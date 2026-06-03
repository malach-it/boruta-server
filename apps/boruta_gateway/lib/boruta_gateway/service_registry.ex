defmodule BorutaGateway.ServiceRegistry do
  @moduledoc false

  require Logger

  use GenServer

  import Ecto.Query

  alias BorutaGateway.Certificate
  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.ServiceRegistry.Record

  @online_status "online"
  @offline_status "offline"
  @touch_interval 5_000
  @touch_rpc_timeout 1_000
  @unresponsive_memory_duration 30_000
  @touch_message :touch_service_registry_record
  @changed_channel "service_registry_records_changed"
  @root_node_name "__cluster_ca__"
  @root_ip_address "__cluster_ca__"
  @root_status "root"

  @spec list_records() :: list(Record.t())
  def list_records do
    case Process.whereis(__MODULE__) do
      nil -> repo_list_records()
      _pid -> GenServer.call(__MODULE__, :list_records)
    end
  end

  defp repo_list_records do
    Record
    |> order_by([record], asc: record.node_name, asc: record.ip_address)
    |> Repo.all()
  end

  def hydrate do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, :hydrate)
    end
  end

  @spec all() :: %{optional(String.t()) => Record.t()}
  def all do
    case Process.whereis(__MODULE__) do
      nil -> repo_list_records() |> load_record_certificates() |> structure_records()
      _pid -> GenServer.call(__MODULE__, :all)
    end
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(options \\ []) do
    case Keyword.fetch(options, :name) do
      {:ok, nil} -> GenServer.start_link(__MODULE__, :ok)
      {:ok, name} -> GenServer.start_link(__MODULE__, :ok, name: name)
      :error -> GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end
  end

  @impl GenServer
  def init(:ok) do
    Process.flag(:trap_exit, true)

    listener = subscribe()
    root_record = ensure_root_record!()
    Certificate.ensure!(root_ca(root_record))
    record = upsert_current_record!()

    records =
      repo_list_records()
      |> load_record_certificates()
      |> structure_records()

    schedule_touch()

    {:ok,
     %{
       ip_address: record.ip_address,
       node_name: record.node_name,
       records: records,
       unresponsive_since: %{},
       listener: listener
     }}
  end

  @impl GenServer
  def handle_call(:all, _from, %{records: records} = state) do
    {:reply, records, state}
  end

  @impl GenServer
  def handle_call(:list_records, _from, %{records: records} = state) do
    {:reply, list_cached_records(records), state}
  end

  @impl GenServer
  def handle_call(:hydrate, _from, state) do
    records =
      repo_list_records()
      |> load_record_certificates()
      |> structure_records()

    state = Map.put(state, :records, records)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(
        @touch_message,
        %{ip_address: ip_address, node_name: node_name, records: records} = state
      ) do
    touch_record!(ip_address, node_name)

    {unresponsive_since, deleted_record_ids} =
      rpc_touch_record_nodes(
        records,
        ip_address,
        node_name,
        Map.get(state, :unresponsive_since, %{})
      )

    state =
      state
      |> Map.put(:records, remove_records(records, deleted_record_ids))
      |> Map.put(:unresponsive_since, unresponsive_since)

    schedule_touch()

    {:noreply, state}
  end

  def handle_info({:EXIT, _port, :normal}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:notification, _pid, _ref, @changed_channel, payload},
        %{records: records} = state
      ) do
    payload = Jason.decode!(payload)
    records = update_records(records, payload)
    load_record_certificates(records)

    state = Map.put(state, :records, records)

    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, %{ip_address: ip_address, node_name: node_name} = state) do
    if reason not in [:normal, :shutdown] do
      Logger.error(inspect(reason))
    end

    listener = state[:listener]

    if listener do
      Process.exit(listener, :normal)
    end

    mark_record_offline!(ip_address, node_name)
    :ok
  end

  @spec upsert_current_record!() :: Record.t()
  def upsert_current_record! do
    timestamp = utc_now_second()

    attrs = %{
      node_name: ConfigurationLoader.node_name(),
      erlang_node_name: erlang_node_name(),
      ip_address: current_ip_address(),
      aliases: ConfigurationLoader.aliases(),
      certificate: Certificate.pem(),
      configuration: current_configuration(),
      status: @online_status
    }

    %Record{}
    |> Record.changeset(attrs)
    |> Repo.insert!(
      on_conflict: [
        set: [
          ip_address: attrs.ip_address,
          aliases: attrs.aliases,
          erlang_node_name: attrs.erlang_node_name,
          certificate: attrs.certificate,
          configuration: attrs.configuration,
          status: attrs.status,
          updated_at: timestamp
        ]
      ],
      conflict_target: [:node_name],
      returning: true
    )
  end

  @spec ensure_root_record!() :: Record.t()
  def ensure_root_record! do
    case Repo.get_by(Record, node_name: @root_node_name, ip_address: @root_ip_address) do
      nil -> insert_root_record!()
      record -> ensure_valid_root_record!(record)
    end
  end

  @spec upsert_root_record!(root_ca :: %{certificate: String.t(), private_key: String.t()}) ::
          Record.t()
  def upsert_root_record!(%{certificate: certificate, private_key: private_key} = root_ca) do
    if Certificate.root_ca_valid?(root_ca) do
      attrs = %{
        node_name: @root_node_name,
        erlang_node_name: nil,
        ip_address: @root_ip_address,
        aliases: [],
        certificate: certificate,
        private_key: private_key,
        configuration: %{},
        status: @root_status
      }

      record =
        case Repo.get_by(Record, node_name: @root_node_name, ip_address: @root_ip_address) do
          nil -> %Record{}
          %Record{} = record -> record
        end

      record
      |> Record.changeset(attrs)
      |> Repo.insert_or_update!()
    else
      raise ArgumentError, "invalid cluster CA certificate/private_key pair"
    end
  end

  @spec touch_current_record!() :: non_neg_integer()
  def touch_current_record! do
    touch_record!(current_ip_address(), ConfigurationLoader.node_name())
  end

  @spec touch_record!(String.t(), String.t()) :: non_neg_integer()
  def touch_record!(ip_address, node_name) do
    update_record!(ip_address, node_name, status: @online_status)
  end

  @spec mark_current_record_offline!() :: non_neg_integer()
  def mark_current_record_offline! do
    mark_record_offline!(current_ip_address(), ConfigurationLoader.node_name())
  end

  @spec mark_record_offline!(String.t(), String.t()) :: non_neg_integer()
  def mark_record_offline!(ip_address, node_name) do
    update_record!(ip_address, node_name, status: @offline_status)
  end

  @spec delete_current_record!() :: non_neg_integer()
  def delete_current_record! do
    delete_record!(current_ip_address(), ConfigurationLoader.node_name())
  end

  @spec delete_record!(String.t(), String.t()) :: non_neg_integer()
  def delete_record!(ip_address, node_name) do
    {deleted_count, _records} =
      Repo.delete_all(
        from(record in Record,
          where: record.ip_address == ^ip_address and record.node_name == ^node_name
        )
      )

    deleted_count
  end

  @spec current_ip_address() :: String.t()
  def current_ip_address do
    case host_ips() do
      [ip_address | _addresses] -> ip_address
      [] -> "127.0.0.1"
    end
  end

  defp host_ips do
    case :inet.getifaddrs() do
      {:ok, interfaces} ->
        interfaces
        |> Enum.flat_map(fn {_name, options} -> Keyword.get_values(options, :addr) end)
        |> Enum.reject(&loopback?/1)
        |> Enum.map(&:inet.ntoa/1)
        |> Enum.map(&to_string/1)

      {:error, _reason} ->
        []
    end
  end

  defp loopback?({127, _, _, _}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback?(_address), do: false

  defp update_record!(ip_address, node_name, fields) do
    timestamp = utc_now_second()
    fields = Keyword.put(fields, :updated_at, timestamp)

    {updated_count, _records} =
      Repo.update_all(
        from(record in Record,
          where: record.ip_address == ^ip_address and record.node_name == ^node_name
        ),
        set: fields
      )

    updated_count
  end

  defp insert_root_record! do
    root_ca = Certificate.generate_root_ca_pem!()

    attrs = %{
      node_name: @root_node_name,
      erlang_node_name: nil,
      ip_address: @root_ip_address,
      aliases: [],
      certificate: root_ca.certificate,
      private_key: root_ca.private_key,
      configuration: %{},
      status: @root_status
    }

    %Record{}
    |> Record.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:ip_address, :node_name]
    )

    Repo.get_by!(Record, node_name: @root_node_name, ip_address: @root_ip_address)
  end

  defp ensure_valid_root_record!(%Record{} = record) do
    if Certificate.root_ca_valid?(root_ca(record)) do
      record
    else
      replace_root_record!(record)
    end
  end

  defp replace_root_record!(%Record{} = record) do
    root_ca = Certificate.generate_root_ca_pem!()

    record
    |> Record.changeset(%{
      certificate: root_ca.certificate,
      private_key: root_ca.private_key,
      status: @root_status
    })
    |> Repo.update!()
  end

  defp subscribe do
    case Repo.listen(@changed_channel) do
      {:ok, pid, _ref} -> pid
      error -> raise "could not subscribe to #{@changed_channel}: #{inspect(error)}"
    end
  end

  defp update_records(records, %{"operation" => "INSERT", "record" => record}) do
    case payload_to_record(record) do
      %Record{} = record ->
        records
        |> remove_record(record.id)
        |> put_record(record)

      nil ->
        records
    end
  end

  defp update_records(records, %{"operation" => "UPDATE", "record" => record}) do
    case payload_to_record(record) do
      %Record{} = record ->
        records
        |> remove_record(record.id)
        |> put_record(record)

      nil ->
        records
    end
  end

  defp update_records(records, %{"operation" => "DELETE", "record" => %{"id" => id}}) do
    remove_record(records, id)
  end

  defp load_record_certificates(records) when is_list(records) do
    case records |> Enum.filter(&root_record?/1) |> Enum.map(& &1.certificate) do
      [] -> :ok
      certificates -> Certificate.load_trusted_certificates!(certificates)
    end

    records
  end

  defp load_record_certificates(records) when is_map(records) do
    records
    |> Map.values()
    |> Enum.uniq_by(& &1.id)
    |> load_record_certificates()

    records
  end

  defp payload_to_record(payload) do
    if full_payload?(payload) do
      payload_to_struct(payload)
    else
      Repo.get(Record, payload["id"])
    end
  end

  defp full_payload?(payload) do
    Map.has_key?(payload, "node_name") && Map.has_key?(payload, "ip_address")
  end

  defp payload_to_struct(payload) do
    attrs =
      payload
      |> Enum.map(fn {key, value} -> {String.to_atom(key), cast_payload_value(key, value)} end)

    struct(Record, attrs)
  end

  defp cast_payload_value(key, value) when key in ["inserted_at", "updated_at"] do
    case Ecto.Type.cast(:naive_datetime, value) do
      {:ok, timestamp} -> timestamp
      :error -> value
    end
  end

  defp cast_payload_value("configuration", value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, configuration} -> configuration
      {:error, _error} -> value
    end
  end

  defp cast_payload_value(_key, value), do: value

  defp current_configuration do
    %{
      "certificate" => Certificate.pem(),
      "certificate_paths" => certificate_paths(),
      "services" => [
        %{
          "name" => "HTTP proxy",
          "type" => "proxy",
          "scheme" => "http",
          "enabled" => gateway_env(:proxy_server, true),
          "port" => gateway_env!(:proxy_port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => nil,
          "verify_client_certificate" => false
        },
        %{
          "name" => "HTTPS proxy",
          "type" => "proxy",
          "scheme" => "https",
          "enabled" => gateway_env(:https_proxy_server, true),
          "port" => gateway_env!(:https_proxy_port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => Certificate.pem(),
          "verify_client_certificate" => false
        },
        %{
          "name" => "HTTP gateway",
          "type" => "gateway",
          "scheme" => "http",
          "enabled" => gateway_env(:server, false),
          "port" => gateway_env!(:port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => nil,
          "verify_client_certificate" => false
        },
        %{
          "name" => "HTTPS gateway",
          "type" => "gateway",
          "scheme" => "https",
          "enabled" => gateway_env(:https_server, false),
          "port" => gateway_env!(:https_port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => Certificate.pem(),
          "verify_client_certificate" => gateway_env(:https_verify_client_certificate, false)
        },
        %{
          "name" => "HTTP sidecar gateway",
          "type" => "gateway",
          "scheme" => "http",
          "enabled" => gateway_env(:sidecar_server, false),
          "port" => gateway_env!(:sidecar_port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => nil,
          "verify_client_certificate" => false
        },
        %{
          "name" => "HTTPS sidecar gateway",
          "type" => "gateway",
          "scheme" => "https",
          "enabled" => gateway_env(:sidecar_https_server, false),
          "port" => gateway_env!(:sidecar_https_port),
          "acceptors" => gateway_env(:num_acceptors, 8),
          "certificate" => Certificate.pem(),
          "verify_client_certificate" =>
            gateway_env(:sidecar_https_verify_client_certificate, false)
        }
      ]
    }
  end

  defp certificate_paths do
    Certificate.paths()
    |> Map.take([:certificate, :root_ca_certificate, :trusted_certificates])
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  defp gateway_env(key, default), do: Application.get_env(:boruta_gateway, key, default)
  defp gateway_env!(key), do: Application.fetch_env!(:boruta_gateway, key)

  defp structure_records(records) do
    Enum.reduce(records, %{}, fn record, records ->
      put_record(records, record)
    end)
  end

  defp put_record(records, record) do
    record
    |> record_keys()
    |> Enum.reduce(records, fn key, records ->
      Map.put(records, key, record)
    end)
  end

  defp root_ca(%Record{certificate: certificate, private_key: private_key}) do
    %{certificate: certificate, private_key: private_key}
  end

  defp root_record?(%Record{node_name: @root_node_name, ip_address: @root_ip_address}), do: true
  defp root_record?(_record), do: false

  defp remove_record(records, id) do
    Map.reject(records, fn {_key, record} -> record.id == id end)
  end

  defp remove_records(records, ids) do
    Map.reject(records, fn {_key, record} -> MapSet.member?(ids, record.id) end)
  end

  defp record_keys(record) do
    [record.ip_address | record.aliases || []]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp list_cached_records(records) do
    records
    |> Map.values()
    |> Enum.uniq_by(& &1.id)
    |> sort_records()
  end

  defp sort_records(records) do
    Enum.sort_by(records, fn record -> {record.node_name, record.ip_address} end)
  end

  defp rpc_touch_record_nodes(records, ip_address, node_name, unresponsive_since) do
    now = System.monotonic_time(:millisecond)

    records
    |> list_cached_records()
    |> Enum.reject(&(root_record?(&1) || current_record?(&1, ip_address, node_name)))
    |> Enum.reduce({unresponsive_since, MapSet.new()}, fn record,
                                                          {unresponsive_since, deleted_ids} ->
      case rpc_touch_record_node(record) do
        :ok ->
          {Map.delete(unresponsive_since, unresponsive_key(record)), deleted_ids}

        {:error, reason} ->
          remember_unresponsive_record(record, unresponsive_since, deleted_ids, now, reason)
      end
    end)
  end

  defp current_record?(
         %Record{ip_address: ip_address, node_name: node_name},
         ip_address,
         node_name
       ) do
    true
  end

  defp current_record?(_record, _ip_address, _node_name), do: false

  defp rpc_touch_record_node(%Record{erlang_node_name: erlang_node_name})
       when is_binary(erlang_node_name) and erlang_node_name != "" do
    case :rpc.call(
           String.to_atom(erlang_node_name),
           __MODULE__,
           :touch_current_record!,
           [],
           @touch_rpc_timeout
         ) do
      {:badrpc, reason} -> {:error, reason}
      _response -> :ok
    end
  end

  defp remember_unresponsive_record(record, unresponsive_since, deleted_ids, now, reason) do
    key = unresponsive_key(record)
    unresponsive_at = Map.get(unresponsive_since, key, now)

    if now - unresponsive_at > @unresponsive_memory_duration do
      Logger.warning(
        "Deleting unresponsive service registry record #{inspect(record.node_name)} at #{inspect(record.ip_address)}: #{inspect(reason)}"
      )

      delete_record!(record.ip_address, record.node_name)

      {
        Map.delete(unresponsive_since, key),
        MapSet.put(deleted_ids, record.id)
      }
    else
      {
        Map.put(unresponsive_since, key, unresponsive_at),
        deleted_ids
      }
    end
  end

  defp unresponsive_key(%Record{ip_address: ip_address, node_name: node_name}),
    do: {ip_address, node_name}

  defp erlang_node_name, do: Atom.to_string(node())

  defp utc_now_second do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
  end

  defp schedule_touch do
    Process.send_after(self(), @touch_message, @touch_interval)
  end
end
