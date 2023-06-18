defmodule BorutaGateway.ServiceRegistry.Monitor do
  @moduledoc false

  defmodule State do
    @moduledoc false
    defstruct []
  end

  use GenServer

  require Logger

  alias BorutaGateway.ServiceRegistry

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    :net_kernel.monitor_nodes(true)

    case Node.list() do
      [] ->
        ServiceRegistry.current_node()
        |> ServiceRegistry.upsert_node()

      nodes ->
        _inserts = Enum.map(nodes, fn node ->
          :rpc.call(node, ServiceRegistry, :current_node, [])
        end)
        |> Enum.map(fn node ->
          ServiceRegistry.upsert_node(node)
        end)
    end

    {:ok, %State{}}
  end

  @impl GenServer
  def handle_info({:nodeup, node}, state) do
    node
    |> :rpc.call(ServiceRegistry, :current_node, [])
    |> ServiceRegistry.upsert_node()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:nodedown, node}, state) do
    node
    |> ServiceRegistry.Node.ip_from_name()
    |> ServiceRegistry.delete_by_ip!()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(error, state) do
    error
    |> inspect()
    |> Logger.error()
  end
end
