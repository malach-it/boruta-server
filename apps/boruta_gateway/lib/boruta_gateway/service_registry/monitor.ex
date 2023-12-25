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
    Process.flag(:trap_exit, true)

    ServiceRegistry.current_node()
    |> ServiceRegistry.upsert_node()

    send(self(), :update_routing_table)

    {:ok, %State{}}
  end

  @impl GenServer
  # def handle_info({:nodeup, node}, state) do
  #   node
  #   |> :rpc.call(ServiceRegistry, :current_node, [])
  #   |> ServiceRegistry.upsert_node()

  #   {:noreply, state}
  # end

  # def handle_info({:nodedown, node}, state) do
  #   delete_node(node)

  #   {:noreply, state}
  # end

  def handle_info(:update_routing_table, state) do
    ServiceRegistry.update_current_node_routing_table()

    Process.send_after(self(), :update_routing_table, 5000)

    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.warn("#{inspect(reason)} in handle_info")
    delete_node(ServiceRegistry.current_node().ip)

    {:stop, reason, state}
  end

  def handle_info(error, state) do
    error
    |> inspect()
    |> Logger.error()

    {:noreply, state}
  end

  defp delete_node(node) do
    node
    |> ServiceRegistry.Node.ip_from_name()
    |> ServiceRegistry.delete_by_ip!()
  end
end
