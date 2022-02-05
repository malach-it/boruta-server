defmodule BorutaIdentityWeb.AuthenticableTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts
  alias BorutaIdentityWeb.Authenticable

  @remember_me_cookie "_boruta_identity_web_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BorutaIdentityWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "log_in/3" do
    setup :with_a_request

    test "stores the user token in the session", %{conn: conn, user: user} do
      conn = fetch_query_params(conn)

      conn = Authenticable.log_in(conn, user)
      assert token = get_session(conn, :user_token)
      assert get_session(conn, :live_socket_id) == "users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_user_by_session_token(token)
    end

    test "redirects to the configured path", %{conn: conn, user: user, request: request} do
      conn = %{conn|query_params: %{"request" => request}}

      conn = Authenticable.log_in(conn, user)
      assert redirected_to(conn) == "/user_return_to"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, user: user} do
      conn = fetch_query_params(conn)

      conn = conn |> fetch_cookies() |> Authenticable.log_in(user, %{"remember_me" => "true"})
      assert get_session(conn, :user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :user_token)
      assert max_age == 5_184_000
    end
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
end
