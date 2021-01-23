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
      {:ok, %{status: status, headers: headers, body: body, metrics: metrics}} ->
        conn =
          Enum.reduce(headers, conn, fn
            {"Connection", _value}, conn -> conn
            {"Strict-Transport-Security", _value}, conn -> conn
            {key, value}, conn -> put_resp_header(conn, String.downcase(key), value)
          end)

        conn
        |> assign(:upstream_time, metrics[:total_time] * 1000)
        |> send_resp(status, body)
        |> halt()

      # https://github.com/puzza007/katipo/blob/master/src/katipo.erl#L109
      {:error, %{code: :bad_opts, message: "[{method," <> method_expr}} ->
        method = Regex.run(~r/\w+/, method_expr) |> Enum.at(0)

        conn
        |> send_resp(500, "HTTP method '#{method}' is not supported.")
        |> halt()

      {:error, e} ->
        conn
        |> send_resp(500, inspect(e))
        |> halt()
    end
  end
end
