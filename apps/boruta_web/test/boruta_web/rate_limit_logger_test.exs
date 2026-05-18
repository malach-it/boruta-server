defmodule BorutaWeb.RateLimitLoggerTest do
  use BorutaWeb.ConnCase

  import ExUnit.CaptureLog

  alias BorutaAuth.Plugs.RateLimit

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    Agent.update(RateLimit.Counter, fn _counter -> %{} end)

    on_exit(fn ->
      Logger.configure(level: previous_level)
      Agent.update(RateLimit.Counter, fn _counter -> %{} end)
    end)
  end

  test "logs rate limited requests with the endpoint logger", %{conn: conn} do
    now = :os.system_time(:millisecond)
    remote_ip = ~c"127.0.0.1"

    Agent.update(RateLimit.Counter, fn _counter ->
      %{remote_ip => List.duplicate(now, 600)}
    end)

    log =
      capture_log([level: :info], fn ->
        conn = get(conn, "/.well-known/openid-configuration")

        assert conn.status == 429
      end)

    assert log =~ "boruta_web GET /.well-known/openid-configuration - sent 429 from 127.0.0.1 in "
  end
end
