defmodule BorutaIdentityWeb.AuthenticableTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BorutaIdentityWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "after_sign_in_path" do
    setup :with_a_request

    test "returns root path", %{conn: conn} do
      conn = Plug.Conn.fetch_query_params(conn)

      assert Authenticable.after_sign_in_path(conn) == "/"
    end

    test "returns session stored path if provided", %{conn: conn, request: request} do
      conn = %{conn|query_params: %{"request" => request}}

      assert Authenticable.after_sign_in_path(conn) == "/user_return_to"
    end
  end

  @tag :skip
  test "store_user_session/2"
end
