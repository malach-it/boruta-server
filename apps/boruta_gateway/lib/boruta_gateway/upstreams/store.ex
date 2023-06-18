defmodule BorutaGateway.Upstreams.Store do
  @moduledoc false

  require Logger

  use GenServer

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams.ClientSupervisor
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

  @spec sidecar_match(path_info :: list(String.t())) :: upstream :: Upstream.t() | nil
  def sidecar_match(path_info) do
    GenServer.call(__MODULE__, {:sidecar_match, path_info})
  end

  def all do
    GenServer.call(__MODULE__, :all)
  end

  @impl GenServer
  def handle_call(:all, _from, %{upstreams: upstreams} = state) do
    {:reply, upstreams, state}
  end

  def handle_call({:match, path_info}, _from, %{upstreams: upstreams} = state) do
    upstream =
      with {_prefix_info, upstream} <-
             Enum.find(upstreams["global"] || [], fn {prefix_info, _upstream} ->
               path_info = Enum.take(path_info, length(prefix_info))

               Enum.empty?(prefix_info -- path_info)
             end) do
        upstream
      end

    {:reply, upstream, state}
  end

  def handle_call({:sidecar_match, path_info}, _from, %{upstreams: upstreams} = state) do
    node_name = ConfigurationLoader.node_name()

    upstream =
      with {_prefix_info, upstream} <-
             Enum.find(upstreams[node_name] || [], fn {prefix_info, _upstream} ->
               path_info = Enum.take(path_info, length(prefix_info))

               Enum.empty?(prefix_info -- path_info)
             end) do
        upstream
      end

    {:reply, upstream, state}
  end

  @impl GenServer
  def handle_cast(:hydrate, state) do
    upstreams =
      Repo.all(Upstream)
      |> Enum.map(fn upstream ->
        Upstream.with_http_client(upstream)
      end)
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
      Enum.reduce(upstreams, [], fn {_node_name, upstreams}, acc -> acc ++ (upstreams || []) end)
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
      |> Upstream.with_http_client()

    upstreams
    |> Enum.map(fn {_uri, upstream} -> upstream end)
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
    |> Enum.map(fn {_uri, upstream} -> upstream end)
    |> Enum.map(fn
      %{id: ^updated_id, http_client: http_client} ->
        Upstream.with_http_client(%{updated | http_client: http_client})

      upstream ->
        upstream
    end)
    |> structure()
  end

  defp update_upstreams(upstreams, %{"operation" => "DELETE", "record" => %{"id" => id}}) do
    upstreams
    |> Enum.map(fn {_uri, upstream} -> upstream end)
    |> Enum.reject(fn
      %{id: ^id, http_client: http_client} ->
        # TODO manage failure
        true = ClientSupervisor.kill(http_client)
        true

      _ ->
        false
    end)
    |> structure()
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
end
