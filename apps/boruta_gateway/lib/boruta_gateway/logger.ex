defmodule BorutaGateway.Logger do
  @moduledoc false

  require Logger

  def start do
    handlers = [
      {
        :boruta_gateway_server,
        [:boruta_gateway, :endpoint, :stop],
        &__MODULE__.boruta_gateway_server_handler/4
      },
      {
        :boruta_gateway_requests,
        [:boruta_gateway, :request, :done],
        &__MODULE__.boruta_gateway_request_handler/4
      }
    ]

    for {handler_id, event_name, fun} <- handlers do
      :telemetry.attach(handler_id, event_name, fun, :ok)
    end
  end

  def boruta_gateway_server_handler(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(
          level,
          fn ->
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
          end,
          type: :request
        )
    end
  end

  def boruta_gateway_request_handler(
        _,
        _measurements,
        %{request_time: request_time, conn: conn},
        _
      ) do
    %{method: method, request_path: path, status: status_code} = conn
    node_name = conn.assigns[:node_name]
    status_code = Integer.to_string(status_code)
    remote_ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    status = business_status(conn)

    log_line = [
      "boruta_gateway",
      ?\s,
      "upstream",
      ?\s,
      "request",
      " - ",
      status,
      log_attribute("node_name", node_name),
      log_attribute("remote_ip", remote_ip),
      log_attribute("method", method),
      log_attribute("path", path),
      log_attribute("status_code", status_code),
      log_attribute("request_time", [to_string(request_time), "µs"])
    ]

    log_line =
      log_line
      |> put_access_token(conn)
      |> put_upstream_attributes(conn, request_time)
      |> put_upstream_error(conn)

    Logger.log(
      :info,
      fn -> log_line end,
      type: :business
    )
  end

  defp business_status(conn) do
    case conn.assigns[:upstream] do
      nil -> "failure"
      _upstream -> "success"
    end
  end

  defp put_access_token(log_line, conn) do
    case conn.assigns[:token] do
      nil ->
        log_line

      token ->
        log_line ++
          [
            log_attribute("access_token", token.value)
          ]
    end
  end

  defp put_upstream_attributes(log_line, conn, request_time) do
    case conn.assigns[:upstream] do
      nil ->
        log_line

      upstream ->
        upstream_time = conn.assigns[:upstream_time]

        log_line ++
          [
            log_attribute("upstream_scheme", upstream.scheme),
            log_attribute("upstream_host", upstream.host),
            log_attribute("upstream_port", upstream.port),
            log_attribute("upstream_time", upstream_time && [to_string(upstream_time), "µs"]),
            log_attribute(
              "gateway_time",
              upstream_time && [to_string(request_time - upstream_time), "µs"]
            )
          ]
    end
  end

  defp put_upstream_error(log_line, conn) do
    case conn.assigns[:upstream_error] do
      nil ->
        log_line

      error ->
        log_line ++ [log_attribute("upstream_error", ~s["#{inspect(error)}"])]
    end
  end

  defp log_attribute(_key, nil), do: ""
  defp log_attribute(key, attribute), do: " #{key}=#{attribute}"

  # From Phoenix.Logger
  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  defp connection_type(:set_chunked), do: "chunked"
  defp connection_type(_), do: "sent"

  defp duration(nil), do: ["0", "µs"]

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end
end
