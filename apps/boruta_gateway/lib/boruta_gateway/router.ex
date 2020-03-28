defmodule BorutaGateway.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: BorutaGateway.GatewayPipeline
end
