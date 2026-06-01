defmodule BorutaAuth.EpmdClusterConnector do
  @moduledoc false

  use GenServer

  @connect_interval 5_000
  @connect_message :connect_epmd_cluster_hosts

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  @impl GenServer
  def init(options) do
    hosts =
      options
      |> Keyword.get(:hosts, hosts_from_env())
      |> reject_current_node()

    case hosts do
      [] ->
        :ignore

      hosts ->
        send(self(), @connect_message)
        {:ok, %{hosts: hosts}}
    end
  end

  @impl GenServer
  def handle_info(@connect_message, %{hosts: hosts} = state) do
    connect_hosts(hosts)
    schedule_connect()

    {:noreply, state}
  end

  @spec hosts_from_env() :: list(node())
  def hosts_from_env do
    "LIBCLUSTER_HOSTS"
    |> System.get_env("")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_atom/1)
  end

  defp reject_current_node(hosts) do
    Enum.reject(hosts, &(&1 == node()))
  end

  defp connect_hosts(hosts) do
    connected_nodes = Node.list()

    hosts
    |> Enum.reject(&(&1 in connected_nodes))
    |> Enum.each(&Node.connect/1)
  end

  defp schedule_connect do
    Process.send_after(self(), @connect_message, @connect_interval)
  end
end
