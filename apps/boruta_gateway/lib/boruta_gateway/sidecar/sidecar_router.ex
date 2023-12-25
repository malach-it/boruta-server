defmodule BorutaGateway.SidecarRouter do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: BorutaGateway.MicrogatewayPipeline
end
