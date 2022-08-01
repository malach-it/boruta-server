defmodule BorutaGateway.Logger do
  @moduledoc false

  require Logger

  def start do
    handlers = [
      {
        :boruta_gateway_requests,
        [:boruta_gateway, :endpoint, :stop],
        &__MODULE__.boruta_gateway_request_handler/4
      }
    ]

    for {handler_id, event_name, fun} <- handlers do
      :telemetry.attach(handler_id, event_name, fun, :ok)
    end
  end

  def boruta_gateway_request_handler(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{method: method, request_path: path, status: status, state: state} = conn
          status = Integer.to_string(status)

          [
            "boruta_gateway",
            ?\s,
            method,
            ?\s,
            path,
            " - ",
            connection_type(state),
            ?\s,
            status,
            " in ",
            duration(duration)
          ]
        end)
    end
  end

  # From Phoenix.Logger
  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  defp connection_type(:set_chunked), do: "chunked"
  defp connection_type(_), do: "sent"

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end
end
