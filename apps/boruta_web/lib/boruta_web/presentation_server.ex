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

  def cancel_presentation(code) do
    GenServer.cast(__MODULE__, {:cancel_presentation, code})
  end

  def message(code, message) do
    GenServer.cast(__MODULE__, {:message, code, message})
  end

  def handle_call({:start_presentation, code}, {pid, _}, state) do
    presentations =
      Map.put(
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
    send_presentation_message(state, code, {:authenticated, redirect_uri})

    {:noreply, delete_presentation(state, code)}
  end

  def handle_cast({:cancel_presentation, code}, state) do
    {:noreply, delete_presentation(state, code)}
  end

  def handle_cast({:message, code, message}, state) do
    send_presentation_message(state, code, {:message, message})

    {:noreply, delete_presentation(state, code)}
  end

  defp send_presentation_message(state, code, message) do
    case state.presentations[code] do
      nil ->
        :ok

      presentation ->
        send(presentation[:pid], message)
    end
  end

  defp delete_presentation(state, code) do
    %{state | presentations: Map.delete(state.presentations, code)}
  end
end
