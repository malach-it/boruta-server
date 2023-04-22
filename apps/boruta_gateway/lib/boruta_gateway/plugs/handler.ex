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
    start = System.system_time(:microsecond)
    case Client.request(upstream, conn) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        now = System.system_time(:microsecond)
        request_time = now - start
        conn =
          Enum.reduce(headers, conn, fn
            {"connection", _value}, conn -> conn
            {"strict-transport-security", _value}, conn -> conn
            {"host", _value}, conn -> put_resp_header(conn, "host", conn.host)
            {key, value}, conn -> put_resp_header(conn, String.downcase(key), value)
          end)

        conn
        |> assign(:upstream_time, request_time)
        |> send_resp(status, body)
        |> halt()

      {:error, error} ->
        now = System.system_time(:microsecond)
        request_time = now - start

        conn
        |> assign(:upstream_time, request_time)
        |> assign(:upstream_error, error)
        |> send_resp(500, inspect(error))
        |> halt()
    end
  end
end
