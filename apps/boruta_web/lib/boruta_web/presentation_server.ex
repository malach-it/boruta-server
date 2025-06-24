defmodule BorutaWeb.PresentationServer do
  @moduledoc false

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %{presentations: %{}}}
  end

  def start_presentation(code) do
    GenServer.call(__MODULE__, {:start_presentation, code})
  end

  def authenticated(code, redirect_uri) do
    GenServer.cast(__MODULE__, {:authenticated, code, redirect_uri})
  end

  def message(code, message) do
    GenServer.cast(__MODULE__, {:message, code, message})
  end

  def handle_call({:start_presentation, code}, {pid, _}, state) do
    presentations = Map.put(
      state.presentations,
      code,
      %{
        start: :os.system_time(:microsecond),
        pid: pid
      }
    )
    {:reply, :ok, %{state | presentations: presentations}}
  end

  def handle_cast({:authenticated, code, redirect_uri}, state) do
    case state.presentations[code] do
      nil -> :ok
      presentation ->
        send(presentation[:pid], {:authenticated, redirect_uri})
    end

    {:noreply, Map.delete(state, code)}
  end

  def handle_cast({:message, code, message}, state) do
    case state.presentations[code] do
      nil -> :ok
      presentation ->
        send(presentation[:pid], {:message, message})
    end

    {:noreply, Map.delete(state, code)}
  end
end
