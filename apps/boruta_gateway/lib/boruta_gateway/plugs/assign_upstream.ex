defmodule BorutaGateway.Plug.AssignUpstream do
  @moduledoc false

  import Plug.Conn

  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  require Logger

  def init(options), do: options

  def call(%Plug.Conn{
    path_info: path_info
  } = conn, _options) do
    case Upstreams.match(path_info) do
      %Upstream{} = upstream ->
        assign(conn, :upstream, upstream)
      nil ->
        conn
        |> send_resp(404, "no upstream found")
        |> halt()
    end
  end
end
