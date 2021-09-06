defmodule BorutaAdminWeb.MetricsChannelTest do
  use BorutaAdminWeb.ChannelCase

  alias BorutaAdminWeb.UserSocket
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  test "fails when user is not connected" do
    assert connect(UserSocket, %{"token" => "bad token"}, %{}) == :error
  end

  describe "user is connected" do
    setup do
      token = "token_authorized_by_bypass"

      {:ok, _, socket} =
        socket(BorutaAdminWeb.UserSocket, "user_id", %{token: token})
        |> subscribe_and_join(BorutaAdminWeb.MetricsChannel, "metrics:lobby")

      {:ok, socket: socket, token: token}
    end
    setup :with_authenticated_user

    test "connects", %{token: token} do
      case connect(UserSocket, %{"token" => token}, %{}) do
        {:ok, _socket} -> assert true
        _ -> assert false
      end
    end

    test "send boruta_gateway metrics when request triggered" do
      # TODO change for an internal server
      upstream = %Upstream{scheme: "http", host: "httpbin.org", port: 80, uris: ["/"]}

      Sandbox.unboxed_run(BorutaGateway.Repo, fn ->
        try do
          {:ok, _upstream} = BorutaGateway.Repo.insert(upstream)
          :timer.sleep(100)

          :katipo.req(:katipo_pool, %{
            method: :get,
            url: "http://localhost:7777"
          })

          :timer.sleep(1000)

          assert_broadcast("boruta_gateway", %{
            request: %{
              start_time: _,
              gateway_time: _,
              upstream_time: _,
              request_time: _
            }
          })
        after
          BorutaGateway.Repo.delete_all(Upstream)
        end
      end)
    end
  end
end
