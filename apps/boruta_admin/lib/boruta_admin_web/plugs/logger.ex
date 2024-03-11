defmodule BorutaAdminWeb.Logger do
  @moduledoc false

  require Logger
  alias Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  @impl true
  def call(conn, level) do
    start = System.monotonic_time()

    Conn.register_before_send(
      conn,
      fn conn ->
        Logger.log(
          level,
          fn ->
            remote_ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
            stop = System.monotonic_time()
            duration = System.convert_time_unit(stop - start, :native, :microsecond)
            status = Integer.to_string(conn.status)

            [
              "boruta_admin",
              ?\s,
              conn.method,
              ?\s,
              conn.request_path,
              " - ",
              connection_type(conn.state),
              ?\s,
              status,
              " from ",
              remote_ip,
              " in ",
              duration(duration)
            ]
          end,
          type: :request
        )

        conn
      end
    )
  end

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end

  defp connection_type(%{state: :set_chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"
end
