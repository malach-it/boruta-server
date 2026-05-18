defmodule BorutaGateway.LoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Plug.Conn
  import Plug.Test

  alias Boruta.Oauth.Token
  alias BorutaGateway.Logger
  alias BorutaGateway.Upstreams.Upstream

  setup do
    previous_level = Elixir.Logger.level()
    Elixir.Logger.configure(level: :info)

    on_exit(fn -> Elixir.Logger.configure(level: previous_level) end)
  end

  describe "authorization business logs" do
    test "logs authorization success events" do
      upstream = upstream(%{required_scopes: %{"GET" => ["read"]}})
      token = %Token{type: "access_token", value: "access-token", sub: "user-id"}
      conn = gateway_conn(upstream)

      log =
        capture_log([level: :info], fn ->
          Logger.boruta_gateway_authorization_authorize_success_handler(
            nil,
            %{},
            %{conn: conn, upstream: upstream, token: token},
            nil
          )
        end)

      assert log =~
               "boruta_gateway authorization authorize - success node_name=global method=GET path=/protected access_token=access-token sub=user-id required_scopes=read upstream_scheme=http upstream_host=example.test upstream_port=80"
    end

    test "logs authorization failure events" do
      upstream = upstream(%{required_scopes: %{"GET" => ["read"]}})
      conn = gateway_conn(upstream)

      log =
        capture_log([level: :info], fn ->
          Logger.boruta_gateway_authorization_authorize_failure_handler(
            nil,
            %{},
            %{
              conn: conn,
              upstream: upstream,
              status: 401,
              error: "unauthorized"
            },
            nil
          )
        end)

      assert log =~
               "boruta_gateway authorization authorize - failure node_name=global method=GET path=/protected status=401 error=unauthorized required_scopes=read upstream_scheme=http upstream_host=example.test upstream_port=80"
    end
  end

  defp gateway_conn(upstream) do
    :get
    |> conn("/protected")
    |> assign(:node_name, "global")
    |> assign(:upstream, upstream)
  end

  defp upstream(attrs) do
    struct!(
      Upstream,
      Map.merge(
        %{
          scheme: "http",
          host: "example.test",
          port: 80,
          required_scopes: %{}
        },
        attrs
      )
    )
  end
end
