defmodule BorutaGateway.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias BorutaGateway.Upstreams.Upstream

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  describe "request_handler/4" do
    test "logs a request line parseable by the admin dashboard" do
      log =
        capture_log([level: :info], fn ->
          BorutaGateway.Logger.request_handler(
            [:boruta_gateway, :request, :stop],
            %{duration: 1_500},
            %{
              request_id: "request-id",
              method: "GET",
              path: "/upstream",
              status: 200,
              remote_ip: ~c"127.0.0.1",
              tls: "mtls"
            },
            :ok
          )
        end)

      assert log =~ "request_id=request-id"
      assert log =~ "boruta_gateway GET /upstream - sent 200 from 127.0.0.1 in 1ms"
      refute log =~ "tls=mtls"
    end
  end

  describe "business_handler/4" do
    test "logs gateway timings parseable by the admin dashboard" do
      log =
        capture_log([level: :info], fn ->
          BorutaGateway.Logger.business_handler(
            [:boruta_gateway, :proxy, :success],
            %{
              request_time: 1_500,
              gateway_time: 500,
              upstream_time: 1_000
            },
            %{
              request_id: "request-id",
              upstream: %Upstream{id: "upstream-id", host: "example.com", port: 443},
              upstream_tls: "mtls"
            },
            :ok
          )
        end)

      assert log =~ "request_id=request-id"
      assert log =~ "boruta_gateway gateway proxy - success"
      assert log =~ "upstream_id=upstream-id"
      assert log =~ "upstream_host=example.com"
      assert log =~ "upstream_port=443"
      assert log =~ "upstream_tls=mtls"
      assert log =~ "request_time=1500"
      assert log =~ "gateway_time=500"
      assert log =~ "upstream_time=1000"
    end
  end
end
