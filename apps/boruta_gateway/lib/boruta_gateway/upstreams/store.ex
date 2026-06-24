defmodule BorutaGateway.Upstreams.Store do
  @moduledoc false

  require Logger

  use GenServer

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams.Upstream

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    subscribe()
    hydrate()
    {:ok, %{hydrated: false, upstreams: %{}, listener: nil}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.error(inspect(reason))

    listener = state[:listener]

    if listener do
      Process.exit(listener, :normal)
    end

    :normal
  end

  def hydrate do
    GenServer.cast(__MODULE__, :hydrate)
  end

  def subscribe do
    GenServer.cast(__MODULE__, :subscribe)
  end

  @spec match(path_info :: list(String.t())) :: upstream :: Upstream.t() | nil
  def match(path_info) do
    GenServer.call(__MODULE__, {:match, path_info})
  end

  @spec match(host :: String.t() | nil, path_info :: list(String.t())) ::
          upstream :: Upstream.t() | nil
  def match(host, path_info) do
    GenServer.call(__MODULE__, {:match, host, path_info})
  end

  @spec sidecar_match(path_info :: list(String.t())) :: upstream :: Upstream.t() | nil
  def sidecar_match(path_info) do
    GenServer.call(__MODULE__, {:sidecar_match, path_info})
  end

  @spec sidecar_match(host :: String.t() | nil, path_info :: list(String.t())) ::
          upstream :: Upstream.t() | nil
  def sidecar_match(host, path_info) do
    GenServer.call(__MODULE__, {:sidecar_match, host, path_info})
  end

  def all do
    GenServer.call(__MODULE__, :all)
  end

  @impl GenServer
  def handle_call(:all, _from, %{upstreams: upstreams} = state) do
    {:reply, upstreams, state}
  end

  def handle_call({:match, path_info}, _from, %{upstreams: upstreams} = state) do
    {:reply, match_upstream(upstreams["global"] || [], nil, path_info), state}
  end

  def handle_call({:match, host, path_info}, _from, %{upstreams: upstreams} = state) do
    {:reply, match_upstream(upstreams["global"] || [], host, path_info), state}
  end

  def handle_call({:sidecar_match, path_info}, _from, %{upstreams: upstreams} = state) do
    node_name = ConfigurationLoader.node_name()

    {:reply, match_upstream(upstreams[node_name] || [], nil, path_info), state}
  end

  def handle_call({:sidecar_match, host, path_info}, _from, %{upstreams: upstreams} = state) do
    node_name = ConfigurationLoader.node_name()

    {:reply, match_upstream(upstreams[node_name] || [], host, path_info), state}
  end

  @impl GenServer
  def handle_cast(:hydrate, state) do
    upstreams =
      Repo.all(Upstream)
      |> structure()

    {:noreply, %{state | hydrated: true, upstreams: upstreams}}
  rescue
    error ->
      Logger.error(inspect(error))
      {:stop, error, state}
  end

  @impl GenServer
  def handle_cast(:subscribe, state) do
    case Repo.listen("upstreams_changed") do
      {:ok, pid, _ref} -> {:noreply, %{state | listener: pid}}
      error -> {:stop, error, state}
    end
  end

  @impl GenServer
  def handle_info(
        {:notification, _pid, _ref, "upstreams_changed", payload},
        %{upstreams: upstreams} = state
      ) do
    upstreams =
      upstream_records(upstreams)
      |> update_upstreams(Jason.decode!(payload))

    state = %{state | upstreams: upstreams}

    {:noreply, state}
  end

  defp update_upstreams(upstreams, %{"operation" => "INSERT", "record" => record}) do
    new =
      struct(
        Upstream,
        Enum.map(record, fn {key, value} -> {String.to_atom(key), value} end)
      )

    upstreams
    |> List.insert_at(0, new)
    |> structure()
  end

  defp update_upstreams(upstreams, %{"operation" => "UPDATE", "record" => record}) do
    updated =
      struct(
        Upstream,
        Enum.map(record, fn {key, value} -> {String.to_atom(key), value} end)
      )

    updated_id = updated.id

    upstreams
    |> Enum.map(fn
      %{id: ^updated_id} ->
        updated

      upstream ->
        upstream
    end)
    |> structure()
  end

  defp update_upstreams(upstreams, %{"operation" => "DELETE", "record" => %{"id" => id}}) do
    upstreams
    |> Enum.reject(fn
      %{id: ^id} -> true
      _ -> false
    end)
    |> structure()
  end

  defp upstream_records(upstreams) do
    upstreams
    |> Enum.flat_map(fn {_node_name, upstreams} -> upstreams || [] end)
    |> Enum.map(fn {_uri, upstream} -> upstream end)
    |> Enum.uniq_by(& &1.id)
  end

  defp structure(upstreams) do
    Enum.reduce(upstreams, [], fn upstream, acc ->
      (acc ++
         Enum.map(upstream.uris, fn prefix ->
           prefix_info = String.split(prefix, "/", trim: true)

           {prefix_info, upstream}
         end))
      |> Enum.sort_by(fn {path_info, _upstream} -> length(path_info) end, :desc)
    end)
    |> Enum.group_by(fn {_path_info, %Upstream{node_name: node_name}} -> node_name end)
  end

  defp match_upstream(upstreams, host, path_info) do
    match_hosted_upstream(upstreams, normalize_host(host), path_info) ||
      match_unhosted_upstream(upstreams, path_info)
  end

  defp match_hosted_upstream(_upstreams, nil, _path_info), do: nil

  defp match_hosted_upstream(upstreams, host, path_info) do
    find_matching_upstream(upstreams, path_info, fn upstream ->
      normalize_host(upstream.virtual_host) == host
    end)
  end

  defp match_unhosted_upstream(upstreams, path_info) do
    find_matching_upstream(upstreams, path_info, fn upstream -> is_nil(upstream.virtual_host) end)
  end

  defp find_matching_upstream(upstreams, path_info, upstream_matches?) do
    upstreams
    |> Enum.find(fn {prefix_info, upstream} ->
      path_matches?(prefix_info, path_info) && upstream_matches?.(upstream)
    end)
    |> case do
      {_prefix_info, upstream} -> upstream
      nil -> nil
    end
  end

  defp path_matches?(prefix_info, path_info) do
    Enum.take(path_info, length(prefix_info)) == prefix_info
  end

  defp normalize_host(nil), do: nil

  defp normalize_host(host) do
    host
    |> String.split(":", parts: 2)
    |> List.first()
    |> String.downcase()
  end
end
