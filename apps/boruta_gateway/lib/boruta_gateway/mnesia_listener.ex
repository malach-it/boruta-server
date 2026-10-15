defmodule BorutaGateway.MnesiaListener do
  @moduledoc false

  use GenServer

  def start_link(channel, subscriber) do
    table =
      case channel do
        "upstreams_changed" -> :upstreams
        "service_registry_records_changed" -> :service_registry_records
      end

    with {:ok, pid} <- GenServer.start_link(__MODULE__, {table, channel, subscriber}) do
      {:ok, pid, GenServer.call(pid, :ref)}
    end
  end

  @impl GenServer
  def init({table, channel, subscriber}) do
    {:ok, _node} = :mnesia.subscribe({:table, table, :simple})
    monitor = Process.monitor(subscriber)
    {:ok, {channel, subscriber, make_ref(), monitor}}
  end

  @impl GenServer
  def handle_call(:ref, _from, {_channel, _subscriber, ref, _monitor} = state) do
    {:reply, ref, state}
  end

  @impl GenServer
  def handle_info({:mnesia_table_event, _event}, {channel, subscriber, ref, _monitor} = state) do
    send(subscriber, {:mnesia_changed, ref, channel})
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, monitor, :process, subscriber, _reason},
        {_channel, subscriber, _ref, monitor} = state
      ) do
    {:stop, :normal, state}
  end
end
