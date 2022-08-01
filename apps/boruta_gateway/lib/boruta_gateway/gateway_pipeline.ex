defmodule BorutaGateway.GatewayPipeline do
  @moduledoc false

  use Plug.Router

  plug BorutaGateway.Plug.Metrics
  plug BorutaGateway.Plug.AssignUpstream
  plug BorutaGateway.Plug.Authorize
  plug Plug.RequestId
  plug Plug.Telemetry,
    event_prefix: [:boruta_gateway, :endpoint]

  plug :match
  plug :dispatch

  match _, to: BorutaGateway.Plug.Handler, init_opts: []
end
