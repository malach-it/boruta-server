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
      upstream_time = floor(Map.get(conn.assigns, :upstream_time, 0))
      request_time = now - start

      :telemetry.execute(
        [:boruta_gateway, :request, :done],
        %{
          gateway_time: request_time - upstream_time,
          upstream_time: upstream_time,
          request_time: request_time,
          status_code: conn.status
        },
        %{request_path: request_path, method: method, start_time: start}
      )

      conn
    end)
  end
end
