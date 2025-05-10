defmodule BorutaWeb.Plugs.RateLimit do
  @moduledoc false

  defmodule Counter do
    @moduledoc false
    use Agent

    @base_unit :millisecond

    @memory_length 50

    @time_unit_stamps [
      millisecond: 1,
      second: 1_000,
      minute: 60 * 1_000
    ]

    def start_link(_args) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def get(ip, time_unit) do
      Agent.get(__MODULE__, fn counter ->
        Map.get(counter, ip, [])
      end)
      |> Enum.count(fn timestamp ->
        timestamp > :os.system_time(@base_unit) - @time_unit_stamps[time_unit]
      end)
    end

    def throttling_timeout(ip, count, time_unit, penality) do
      now = :os.system_time(@base_unit)

      request_rates = Agent.get(__MODULE__, fn counter ->
        Map.get(counter, ip, [])
        |> Enum.filter(fn timestamp ->
          timestamp > now - @memory_length * @time_unit_stamps[time_unit]
        end)
      end)
      |> Enum.group_by(fn timestamp ->
        div(timestamp, @time_unit_stamps[time_unit])
      end)

      timeout = Enum.map(0..@memory_length - 1, fn i ->
        current = floor(now - (i * @time_unit_stamps[time_unit]))

        Map.get(request_rates, div(current, @time_unit_stamps[time_unit]), [])
      end)
      |> Enum.reverse()
      |> Enum.map(fn
        [] -> count / @time_unit_stamps[time_unit]
        timestamps -> Enum.count(timestamps) / @time_unit_stamps[time_unit]
      end)
      |> Enum.reduce(1, fn factor, acc ->
        acc * factor * (@time_unit_stamps[time_unit] / count)
      end)

      case timeout <= 1 do
        true -> 0
        false -> floor(timeout * penality)
      end
    end

    def increment(ip, time_unit) do
      Agent.update(__MODULE__, fn counter ->
        timestamps =
          Map.get(counter, ip, [])
          |> Enum.filter(fn timestamp ->
            timestamp > :os.system_time(@base_unit) - @memory_length * @time_unit_stamps[time_unit]
          end)

        Map.put(
          counter,
          ip,
          [:os.system_time(@base_unit) | timestamps]
        )
      end)
    end
  end

  use BorutaWeb, :controller

  def init(options), do: options

  def call(conn, options) do
    remote_ip = :inet.ntoa(conn.remote_ip)

    Counter.increment(remote_ip, options[:time_unit])

    max_timeout = options[:timeout]

    case Counter.throttling_timeout(
      remote_ip,
      options[:count],
      options[:time_unit],
      options[:penality]
    ) do
      timeout when timeout < max_timeout ->
        :timer.sleep(timeout)
        conn
      _ ->
        send_resp(conn, 429, "")
    end
  end
end
