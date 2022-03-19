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

    @tag :skip
    test "send boruta_gateway metrics when request triggered" do
    end
  end
end
