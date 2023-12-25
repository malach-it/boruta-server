defmodule BorutaGateway.Router do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: BorutaGateway.GatewayPipeline
end
