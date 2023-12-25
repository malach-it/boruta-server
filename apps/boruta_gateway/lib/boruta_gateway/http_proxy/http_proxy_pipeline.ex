defmodule BorutaGateway.HttpProxyPipeline do
  @moduledoc false

  use Plug.Router

  plug(Plug.RequestId)

  plug(Plug.Telemetry,
    event_prefix: [:boruta_gateway, :http_proxy]
  )

  plug(:match)
  plug(:dispatch)
  match(_, to: BorutaGateway.HttpProxy.Handler, init_opts: [])
end
