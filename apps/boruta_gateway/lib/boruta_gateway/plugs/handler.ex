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
      {:ok, %{status: status, headers: headers, body: body}} ->
        conn =
          Enum.reduce(headers, conn, fn
            {"Connection", _value}, conn -> conn
            {"Strict-Transport-Security", _value}, conn -> conn
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
