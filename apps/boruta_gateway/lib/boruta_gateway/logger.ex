defmodule BorutaGateway.Logger do
  @moduledoc false

  require Logger

  def start do
    handlers = [
      {
        :boruta_gateway_requests,
        [:boruta_gateway, :request, :stop],
        &__MODULE__.request_handler/4
      },
      {
        :boruta_gateway_business_success,
        [:boruta_gateway, :proxy, :success],
        &__MODULE__.business_handler/4
      },
      {
        :boruta_gateway_business_failure,
        [:boruta_gateway, :proxy, :failure],
        &__MODULE__.business_handler/4
      }
    ]

    for {handler_id, event_name, fun} <- handlers do
      :telemetry.attach(handler_id, event_name, fun, :ok)
    end
  end

  def request_handler(
        _event,
        %{duration: duration},
        %{
          request_id: request_id,
          method: method,
          path: path,
          status: status,
          remote_ip: remote_ip
        } = metadata,
        _config
      ) do
    request(%{
      request_id: request_id,
      method: method,
      path: path,
      status: status,
      remote_ip: remote_ip,
      duration: duration,
      tls: Map.get(metadata, :tls)
    })
  end

  def business_handler(
        event,
        %{
          request_time: request_time,
          gateway_time: gateway_time,
          upstream_time: upstream_time
        },
        %{
          request_id: request_id,
          upstream: upstream
        } = metadata,
        _config
      ) do
    business(%{
      request_id: request_id,
      status: event |> List.last() |> Atom.to_string(),
      upstream: upstream,
      request_time: request_time,
      gateway_time: gateway_time,
      upstream_time: upstream_time,
      upstream_tls: Map.get(metadata, :upstream_tls)
    })
  end

  defp request(%{
         request_id: request_id,
         method: method,
         path: path,
         status: status,
         remote_ip: remote_ip,
         duration: duration,
         tls: tls
       }) do
    Logger.log(
      :info,
      fn ->
        [
          "boruta_gateway",
          ?\s,
          method,
          ?\s,
          path,
          " - ",
          "sent",
          ?\s,
          Integer.to_string(status),
          " from ",
          remote_ip,
          log_attribute("tls", tls),
          " in ",
          duration(duration)
        ]
      end,
      application: :boruta_gateway,
      request_id: request_id,
      type: :request
    )
  end

  defp business(%{
         request_id: request_id,
         status: status,
         upstream: upstream,
         request_time: request_time,
         gateway_time: gateway_time,
         upstream_time: upstream_time,
         upstream_tls: upstream_tls
       }) do
    Logger.log(
      :info,
      fn ->
        [
          "boruta_gateway",
          ?\s,
          "gateway",
          ?\s,
          "proxy",
          " - ",
          status,
          log_attribute("upstream_id", upstream && upstream.id),
          log_attribute("upstream_host", upstream && upstream.host),
          log_attribute("upstream_port", upstream && upstream.port),
          log_attribute("upstream_tls", upstream_tls),
          log_attribute("request_time", request_time),
          log_attribute("gateway_time", gateway_time),
          log_attribute("upstream_time", upstream_time)
        ]
      end,
      application: :boruta_gateway,
      request_id: request_id,
      type: :business
    )
  end

  defp log_attribute(_key, nil), do: ""
  defp log_attribute(key, attribute), do: " #{key}=#{attribute}"

  defp duration(duration) do
    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end
end
