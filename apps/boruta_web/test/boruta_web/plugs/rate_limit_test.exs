defmodule BorutaWeb.Plugs.RateLimitTest do
  use ExUnit.Case

  alias BorutaWeb.Plugs.RateLimit

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  describe "rate limiting" do
    test "request passes", %{conn: conn} do
      :timer.sleep(1)
      options = [time_unit: :millisecond, count: 1]
      assert RateLimit.call(conn, options) == conn
    end

    test "request is throttled", %{conn: conn} do
      :timer.sleep(1000)
      b_conn = %{conn | remote_ip: {127, 0, 0, 2}}
      options = [time_unit: :second, count: 5]
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
      assert RateLimit.call(conn, options) == conn
      assert RateLimit.call(b_conn, options) == b_conn
      assert RateLimit.call(conn, options).status == 429
      assert RateLimit.call(b_conn, options).status == 429
    end
  end

  describe "Counter.get" do
    test "gives the count within the time unit range" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second

      assert RateLimit.Counter.get(ip, time_unit) == 0
      Agent.update(RateLimit.Counter, fn _counter -> %{ip => [:os.system_time(:millisecond)]} end)
      assert RateLimit.Counter.get(ip, time_unit) == 1

      Agent.update(RateLimit.Counter, fn _counter ->
        %{ip => [:os.system_time(:millisecond), :os.system_time(:millisecond)]}
      end)

      assert RateLimit.Counter.get(ip, time_unit) == 2

      Agent.update(RateLimit.Counter, fn _counter ->
        %{ip => [:os.system_time(:millisecond), :os.system_time(:millisecond) - 1000]}
      end)

      assert RateLimit.Counter.get(ip, time_unit) == 1
    end
  end

  describe "Counter.increment" do
    test "updates the counter" do
      :timer.sleep(1000)
      ip = :ip
      time_unit = :second

      assert Agent.get(RateLimit.Counter, fn counter ->
               Map.get(counter, ip, []) |> Enum.count()
             end) == 0

      RateLimit.Counter.increment(ip, time_unit)

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} ->
               Enum.count(timestamps)
             end) == 1

      RateLimit.Counter.increment(ip, time_unit)

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} ->
               Enum.count(timestamps)
             end) == 2

      :timer.sleep(1000)
      RateLimit.Counter.increment(ip, time_unit)

      assert Agent.get(RateLimit.Counter, fn %{^ip => timestamps} -> Enum.count(timestamps) end) ==
               1
    end
  end
end
