defmodule BorutaGateway.Plug.Handler do
  @moduledoc false

  import Plug.Conn

  alias BorutaGateway.Upstreams.Client

  require Logger

  def init(options), do: options

  def call(
        %Plug.Conn{
          assigns: %{upstream: upstream}
        } = conn,
        _options
      ) do
    case Client.request(upstream, conn) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        conn =
          Enum.reduce(headers, conn, fn
            {"connection", _value}, conn -> conn
            {"strict-transport-security", _value}, conn -> conn
            {"host", _value}, conn -> put_resp_header(conn, "host", conn.host)
            {key, value}, conn -> put_resp_header(conn, String.downcase(key), value)
          end)

        conn
        |> send_resp(status, body)
        |> halt()

      {:error, e} ->
        conn
        |> send_resp(500, inspect(e))
        |> halt()
    end
  end
end
