defmodule BorutaAdminWeb.MetricsChannel do
  @moduledoc false

  use BorutaAdminWeb, :channel

  def join("metrics:lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_event(measurements) do
    BorutaAdminWeb.Endpoint.broadcast!("metrics:lobby", "boruta_gateway", %{
      request: measurements
    })
  end
end
