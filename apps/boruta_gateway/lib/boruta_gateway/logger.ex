defmodule BorutaGateway.Logger do
  @moduledoc false

  require Logger

  def start do
    handlers = [
      {
        :boruta_gateway_requests,
        [:boruta_gateway, :endpoint, :stop],
        &__MODULE__.boruta_gateway_request_handler/4
      },
      {
        :boruta_gateway_upstream_requests,
        [:finch, :request, :stop],
        &__MODULE__.boruta_gateway_upstream_request_handler/4
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

  def boruta_gateway_upstream_request_handler(
        _,
        %{duration: duration},
        %{request: request, result: result, name: name},
        _
      ) do
    with "finch_gateway_client_" <> _upstream_id <- to_string(name) do
      Logger.log(
        :info,
        fn ->
          %Finch.Request{
            host: upstream_host,
            method: upstream_method,
            path: upstream_path,
            port: upstream_port,
            scheme: upstream_scheme
          } = request

          case result do
            {:ok,
             %Finch.Response{
               status: upstream_status
             }} ->
              [
                "boruta_gateway",
                ?\s,
                "gateway",
                ?\s,
                "upstream",
                " - ",
                "success",
                log_attribute("duration", duration(duration)),
                log_attribute("upstream_host", upstream_host),
                log_attribute("upstream_port", upstream_port),
                log_attribute("upstream_scheme", upstream_scheme),
                log_attribute("upstream_method", upstream_method),
                log_attribute("upstream_path", upstream_path),
                log_attribute("upstream_status", upstream_status)
              ]

            {:error, exception} ->
              [
                "gateway",
                ?\s,
                "upstream",
                " - ",
                "failure",
                log_attribute("duration", duration),
                log_attribute("error", ~s{"#{inspect(exception)}"})
              ]
          end
        end,
        type: :business
      )
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

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    [Integer.to_string(duration), "µs"]
  end
end
