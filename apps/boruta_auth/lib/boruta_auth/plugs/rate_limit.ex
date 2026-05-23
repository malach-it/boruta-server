defmodule BorutaAuth.Plugs.RateLimit do
  @moduledoc false

  import Plug.Conn, only: [halt: 1, send_resp: 3]

  defmodule Counter do
    @moduledoc false
    use Agent

    @base_unit :millisecond

    @default_memory_length 50

    @time_unit_stamps [
      millisecond: 1,
      second: 1_000,
      minute: 60 * 1_000
    ]

    def start_link(_args) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def default_memory_length, do: @default_memory_length

    def get(ip, time_unit) do
      Agent.get(__MODULE__, fn counter ->
        Map.get(counter, ip, [])
      end)
      |> Enum.count(fn timestamp ->
        timestamp > :os.system_time(@base_unit) - @time_unit_stamps[time_unit]
      end)
    end

    def throttling_timeout(ip, count, time_unit, penality) do
      throttling_timeout(ip, count, time_unit, penality, @default_memory_length)
    end

    def throttling_timeout(ip, count, time_unit, penality, memory_length) do
      now = :os.system_time(@base_unit)

      request_rates =
        Agent.get(__MODULE__, fn counter ->
          Map.get(counter, ip, [])
          |> Enum.filter(fn timestamp ->
            timestamp > now - memory_length * @time_unit_stamps[time_unit]
          end)
        end)
        |> Enum.group_by(fn timestamp ->
          div(timestamp, @time_unit_stamps[time_unit])
        end)

      timeout =
        Enum.map(0..(memory_length - 1), fn i ->
          current = floor(now - i * @time_unit_stamps[time_unit])

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
      increment(ip, time_unit, @default_memory_length)
    end

    def increment(ip, time_unit, memory_length) do
      Agent.update(__MODULE__, fn counter ->
        timestamps =
          Map.get(counter, ip, [])
          |> Enum.filter(fn timestamp ->
            timestamp >
              :os.system_time(@base_unit) - memory_length * @time_unit_stamps[time_unit]
          end)

        Map.put(
          counter,
          ip,
          [:os.system_time(@base_unit) | timestamps]
        )
      end)
    end
  end

  def init(options), do: options

  def call(conn, options) do
    remote_ip = :inet.ntoa(conn.remote_ip)
    key = Keyword.get(options, :key, remote_ip)
    max_timeout = options[:timeout]
    count = options[:count]
    time_unit = options[:time_unit]
    memory_length = Keyword.get(options, :memory_length, Counter.default_memory_length())

    throttle(conn, key, count, time_unit, options[:penality], max_timeout, memory_length)
  end

  defp throttle(conn, key, count, time_unit, penality, max_timeout, memory_length) do
    case Counter.throttling_timeout(key, count, time_unit, penality, memory_length) do
      timeout when timeout < max_timeout ->
        :timer.sleep(timeout)

        Counter.increment(key, time_unit, memory_length)
        conn

      _ ->
        send_resp(conn, 429, "") |> halt()
    end
  end
end
