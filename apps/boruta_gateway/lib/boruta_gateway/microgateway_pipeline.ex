defmodule BorutaGateway.MicrogatewayPipeline do
  @moduledoc false

  use Plug.Router

  plug(Plug.RequestId)
  plug(BorutaGateway.Plug.Metrics)
  plug(BorutaGateway.Plug.AssignSidecarUpstream)

  plug(Plug.Telemetry,
    event_prefix: [:boruta_gateway, :endpoint]
  )

  plug(:match)
  plug(BorutaGateway.Plug.Authorize)

  plug(:dispatch)
  match(_, to: BorutaGateway.Plug.Handler, init_opts: [])
end
