defmodule BorutaGateway.HttpProxyRouter do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: BorutaGateway.HttpProxyPipeline
end
