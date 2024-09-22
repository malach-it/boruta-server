defmodule BorutaWeb.PresentationServer do
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

  def authenticated(code, redirect_uri, session_token) do
    GenServer.cast(__MODULE__, {:authenticated, code, redirect_uri, session_token})
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
    {:reply, :ok, %{state| presentations: presentations}}
  end

  def handle_cast({:authenticated, code, redirect_uri, session_token}, state) do
    presentation = state.presentations[code]
    send(presentation[:pid], {:authenticated, redirect_uri, session_token})

    {:noreply, Map.delete(state, code)}
  end
end
