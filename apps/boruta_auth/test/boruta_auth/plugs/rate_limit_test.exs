defmodule BorutaAuth.Plugs.RateLimitTest do
  use ExUnit.Case

  alias BorutaAuth.Plugs.RateLimit

  setup do
    Agent.update(RateLimit.Counter, fn _counter -> %{} end)

    {:ok, conn: Plug.Test.conn(:get, "/")}
  end

  describe "rate limiting" do
    test "request passes", %{conn: conn} do
      :timer.sleep(1)
      options = [time_unit: :millisecond, count: 1, penality: 500, timeout: 5_000]
      assert RateLimit.call(conn, options) == conn
    end

    test "request is throttled", %{conn: conn} do
      :timer.sleep(1000)
      b_conn = %{conn | remote_ip: {127, 0, 0, 2}}
      options = [time_unit: :second, count: 5, penality: 500, timeout: 5_000]
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
    end

    test "request can be tracked with a custom key", %{conn: conn} do
      options = [
        key: {:upstream, "id", "ip"},
        time_unit: :second,
        count: 5,
        penality: 500,
        timeout: 5_000
      ]

      assert RateLimit.call(conn, options) == conn

      assert Agent.get(RateLimit.Counter, fn counter ->
               Map.has_key?(counter, {:upstream, "id", "ip"})
             end)
    end

    test "request can use a custom memory length", %{conn: conn} do
      options = [
        key: {:upstream, "id", "ip"},
        time_unit: :second,
        count: 5,
        penality: 500,
        timeout: 5_000,
        memory_length: 1
      ]

      assert RateLimit.call(conn, options) == conn
    end
  end

  describe "Counter.get" do
    test "gives the count within the time unit range" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second

      assert RateLimit.Counter.get(RateLimit.Counter, ip, time_unit) == 0
      Agent.update(RateLimit.Counter, fn _counter -> %{ip => [:os.system_time(:millisecond)]} end)
      assert RateLimit.Counter.get(RateLimit.Counter, ip, time_unit) == 1

      Agent.update(RateLimit.Counter, fn _counter ->
        %{ip => [:os.system_time(:millisecond), :os.system_time(:millisecond)]}
      end)

      assert RateLimit.Counter.get(RateLimit.Counter, ip, time_unit) == 2

      Agent.update(RateLimit.Counter, fn _counter ->
        %{ip => [:os.system_time(:millisecond), :os.system_time(:millisecond) - 1000]}
      end)

      assert RateLimit.Counter.get(RateLimit.Counter, ip, time_unit) == 1
    end
  end

  describe "Counter.throttling_timeout" do
    test "gives the timeout within the time unit range" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second
      penality = 100
      count = 1

      Agent.update(RateLimit.Counter, fn _counter -> %{} end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               RateLimit.Counter.default_memory_length()
             ) == 0

      Agent.update(RateLimit.Counter, fn _counter -> %{ip => [:os.system_time(:millisecond)]} end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               RateLimit.Counter.default_memory_length()
             ) == 0

      Agent.update(RateLimit.Counter, fn _counter ->
        %{
          ip => [
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond)
          ]
        }
      end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               RateLimit.Counter.default_memory_length()
             ) == 700

      Agent.update(RateLimit.Counter, fn _counter ->
        %{
          ip => [
            :os.system_time(:millisecond) - 1000,
            :os.system_time(:millisecond) - 800,
            :os.system_time(:millisecond)
          ]
        }
      end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               RateLimit.Counter.default_memory_length()
             ) == 200

      Agent.update(RateLimit.Counter, fn _counter ->
        %{ip => [:os.system_time(:millisecond), :os.system_time(:millisecond) - 1000]}
      end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               RateLimit.Counter.default_memory_length()
             ) == 0
    end

    test "accepts a configurable memory length" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second
      penality = 100
      count = 1

      Agent.update(RateLimit.Counter, fn _counter ->
        %{
          ip => [
            :os.system_time(:millisecond),
            :os.system_time(:millisecond),
            :os.system_time(:millisecond)
          ]
        }
      end)

      assert RateLimit.Counter.throttling_timeout(
               RateLimit.Counter,
               ip,
               count,
               time_unit,
               penality,
               1
             ) ==
               300
    end
  end

  describe "Counter.increment" do
    test "updates the counter" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second

      assert Agent.get(RateLimit.Counter, fn counter ->
               Map.get(counter, ip, [])
               |> Enum.count(fn timestamp -> timestamp > :os.system_time(:millisecond) - 1000 end)
             end) == 0

      RateLimit.Counter.increment(
        RateLimit.Counter,
        ip,
        time_unit,
        RateLimit.Counter.default_memory_length()
      )

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} ->
               timestamps
               |> Enum.count(fn timestamp -> timestamp > :os.system_time(:millisecond) - 1000 end)
             end) == 1

      RateLimit.Counter.increment(
        RateLimit.Counter,
        ip,
        time_unit,
        RateLimit.Counter.default_memory_length()
      )

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} ->
               timestamps
               |> Enum.count(fn timestamp -> timestamp > :os.system_time(:millisecond) - 1000 end)
             end) == 2

      :timer.sleep(1000)

      RateLimit.Counter.increment(
        RateLimit.Counter,
        ip,
        time_unit,
        RateLimit.Counter.default_memory_length()
      )

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} ->
               timestamps
               |> Enum.count(fn timestamp -> timestamp > :os.system_time(:millisecond) - 1000 end)
             end) ==
               1
    end
  end
end
