defmodule BorutaWeb.Plugs.RateLimit do
  @moduledoc false

  defmodule Counter do
    use Agent

    @base_unit :millisecond

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
        |> Enum.filter(fn timestamp ->
          timestamp > :os.system_time(@base_unit) - @time_unit_stamps[time_unit]
        end)
        |> Enum.count()
      end)
    end

    def increment(ip, time_unit) do
      Agent.update(__MODULE__, fn counter ->
        timestamps =
          Map.get(counter, ip, [])
          |> Enum.filter(fn timestamp ->
            timestamp > :os.system_time(@base_unit) - @time_unit_stamps[time_unit]
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

    case Counter.get(remote_ip, options[:time_unit]) > options[:count] do
      false ->
        conn

      true ->
        send_resp(conn, 429, "")
    end
  end
end
