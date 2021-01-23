defmodule BorutaWeb.MetricsChannel do
  @moduledoc false

  use BorutaWeb, :channel

  def join("metrics:lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_event(measurements) do
    BorutaWeb.Endpoint.broadcast!("metrics:lobby", "boruta_gateway", %{
      request: measurements
    })
  end
end
