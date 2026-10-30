defmodule BorutaIdentityWeb.SessionsTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable
  alias BorutaIdentityWeb.Sessions

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BorutaIdentityWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Plug.Conn.fetch_query_params()

    %{user: user_fixture(), conn: conn}
  end

  describe "fetch_current_user/2" do
    test "authenticates the bearer token owner ahead of the cookie session", %{
      conn: conn,
      user: user
    } do
      cookie_user = user_fixture()
      client_id = SecureRandom.uuid()
      token = Boruta.Factory.insert(:token, sub: user.id)

      conn =
        conn
        |> with_client_request(client_id)
        |> put_session(:user_token, %{client_id => generate_user_session_token(cookie_user)})
        |> put_req_header("authorization", "bEaReR #{token.value}")
        |> Sessions.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end

    test "rejects invalid authorization without falling back to the session", %{
      conn: conn,
      user: user
    } do
      client_id = SecureRandom.uuid()

      conn =
        conn
        |> with_client_request(client_id)
        |> put_session(:user_token, %{client_id => generate_user_session_token(user)})

      expired =
        Boruta.Factory.insert(:token, sub: user.id, expires_at: System.os_time(:second) - 1)

      revoked = Boruta.Factory.insert(:token, sub: user.id, revoked_at: DateTime.utc_now())
      ownerless = Boruta.Factory.insert(:token)

      for header <- [
            "Bearer invalid",
            "Bearer",
            "Basic credentials",
            "Bearer a b",
            "Bearer #{expired.value}",
            "Bearer #{revoked.value}",
            "Bearer #{ownerless.value}"
          ] do
        result =
          conn |> put_req_header("authorization", header) |> Sessions.fetch_current_user([])

        refute result.assigns.current_user
      end
    end

    test "authenticates only the user session belonging to the requesting client", %{conn: conn} do
      first_user = user_fixture()
      second_user = user_fixture()
      first_token = generate_user_session_token(first_user)
      second_token = generate_user_session_token(second_user)
      first_client_id = SecureRandom.uuid()
      second_client_id = SecureRandom.uuid()
      other_client_id = SecureRandom.uuid()

      conn =
        put_session(conn, :user_token, %{
          first_client_id => first_token,
          second_client_id => second_token
        })

      assert conn
             |> with_client_request(first_client_id)
             |> Sessions.fetch_current_user([])
             |> Map.get(:assigns)
             |> Map.get(:current_user)
             |> Map.get(:id) == first_user.id

      assert conn
             |> with_client_request(second_client_id)
             |> Sessions.fetch_current_user([])
             |> Map.get(:assigns)
             |> Map.get(:current_user)
             |> Map.get(:id) == second_user.id

      refute conn
             |> with_client_request(other_client_id)
             |> Sessions.fetch_current_user([])
             |> Map.get(:assigns)
             |> Map.get(:current_user)
    end

    test "authenticates user from session", %{conn: conn, user: user} do
      user_token = generate_user_session_token(user)
      client_id = SecureRandom.uuid()

      conn =
        conn
        |> with_client_request(client_id)
        |> put_session(:user_token, %{client_id => user_token})
        |> Sessions.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end

    test "does not authenticate if data is missing", %{conn: conn, user: user} do
      _ = generate_user_session_token(user)
      conn = Sessions.fetch_current_user(conn, [])
      refute get_session(conn, :user_token)
      refute conn.assigns.current_user
    end

    test "authenticates user from cookies", %{conn: conn, user: user} do
      client_id = SecureRandom.uuid()

      logged_in_conn =
        conn
        |> fetch_cookies()
        |> with_client_request(client_id)
        |> log_in(user, %{"user" => %{"remember_me" => "true"}})

      user_token = get_session(logged_in_conn, :user_token)[client_id]
      cookie_name = Authenticable.remember_me_cookie(client_id)
      %{value: signed_token} = logged_in_conn.resp_cookies[cookie_name]

      conn =
        conn
        |> with_client_request(client_id)
        |> put_req_cookie(cookie_name, signed_token)
        |> Sessions.fetch_current_user([])

      assert get_session(conn, :user_token) == %{client_id => user_token}
      assert conn.assigns.current_user.id == user.id
    end

    test "remember me cookie does not authenticate another client", %{conn: conn, user: user} do
      client_id = SecureRandom.uuid()

      logged_in_conn =
        conn
        |> fetch_cookies()
        |> with_client_request(client_id)
        |> log_in(user, %{"user" => %{"remember_me" => "true"}})

      cookie_name = Authenticable.remember_me_cookie(client_id)
      %{value: signed_token} = logged_in_conn.resp_cookies[cookie_name]

      conn =
        conn
        |> with_client_request(SecureRandom.uuid())
        |> put_req_cookie(cookie_name, signed_token)
        |> Sessions.fetch_current_user([])

      refute conn.assigns.current_user
      refute get_session(conn, :user_token)
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "redirects if user is authenticated", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user) |> Sessions.redirect_if_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if user is not authenticated", %{conn: conn} do
      conn = Sessions.redirect_if_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> Sessions.require_authenticated_user([])
      assert conn.halted
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "does not redirect if user is authenticated", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user) |> Sessions.require_authenticated_user([])
      refute conn.halted
      refute conn.status
    end
  end

  defp with_client_request(conn, client_id) do
    {:ok, request, _claims} =
      Joken.encode_and_sign(
        %{"client_id" => client_id},
        BorutaIdentityWeb.Token.application_signer()
      )

    %{conn | query_params: %{"request" => request}}
  end
end
