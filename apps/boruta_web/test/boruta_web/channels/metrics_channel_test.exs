defmodule BorutaWeb.MetricsChannelTest do
  use BorutaWeb.ChannelCase
  use BorutaWeb.DataCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaGateway.Upstreams.Upstream
  alias BorutaWeb.UserSocket
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Adapters.SQL.Sandbox

  test "fails when user is not connected" do
    assert connect(UserSocket, %{"token" => "bad token"}, %{}) == :error
  end

  describe "user is connected" do
    setup do
      client = Boruta.Factory.insert(:client)
      resource_owner = user_fixture()

      token =
        Boruta.Factory.insert(:token,
          type: "access_token",
          value: "888",
          client: client,
          sub: resource_owner.id
        )

      {:ok, _, socket} =
        socket(BorutaWeb.UserSocket, "user_id", %{token: token})
        |> subscribe_and_join(BorutaWeb.MetricsChannel, "metrics:lobby")

      {:ok, socket: socket, token: token}
    end

    test "connects", %{token: token} do
      case connect(UserSocket, %{"token" => token.value}, %{}) do
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
