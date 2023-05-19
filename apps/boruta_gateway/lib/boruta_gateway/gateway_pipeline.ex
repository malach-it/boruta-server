defmodule BorutaGateway.GatewayPipeline do
  @moduledoc false

  use Plug.Router

  plug(RemoteIp)
  plug(Plug.RequestId)
  plug(BorutaGateway.Plug.Metrics)
  plug(BorutaGateway.Plug.AssignUpstream)

  plug(Plug.Telemetry,
    event_prefix: [:boruta_gateway, :endpoint]
  )

  plug(:match)
  plug(BorutaGateway.Plug.Authorize)

  plug(:dispatch)
  match(_, to: BorutaGateway.Plug.Handler, init_opts: [])
end
