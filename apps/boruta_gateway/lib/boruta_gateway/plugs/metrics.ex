defmodule BorutaGateway.Plug.Metrics do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  def init(_options), do: []

  def call(
        %Plug.Conn{
          method: method,
          request_path: request_path
        } = conn,
        _options
      ) do
    start = System.system_time(:microsecond)

    register_before_send(conn, fn conn ->
      now = System.system_time(:microsecond)
      request_time = now - start

      :telemetry.execute(
        [:boruta_gateway, :request, :done],
        %{
          request_time: request_time,
          status_code: conn.status
        },
        %{request_path: request_path, method: method, start_time: start}
      )

      conn
    end)
  end
end
