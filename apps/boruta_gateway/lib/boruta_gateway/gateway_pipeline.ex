defmodule BorutaGateway.GatewayPipeline do
  @moduledoc false

  use Plug.Router

  plug(RemoteIp)
  plug(Plug.RequestId)
  plug(BorutaGateway.Plug.Metrics)
  plug :put_secret_key_base
  plug Plug.Session, store: :ets, key: "sid", table: :session


  plug(BorutaGateway.Plug.AssignUpstream)

  plug(Plug.Telemetry,
    event_prefix: [:boruta_gateway, :endpoint]
  )

  plug(:match)
  plug(BorutaGateway.Plug.Authorize)

  plug(:dispatch)
  match(_, to: BorutaGateway.Plug.Handler, init_opts: [])

  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, "3Th202KTDN8QkzPba/VrThCrD70xTA5k1NsG8Ux6P8yovb5b0MHzo9/VpFmvck/2"
  end
end
