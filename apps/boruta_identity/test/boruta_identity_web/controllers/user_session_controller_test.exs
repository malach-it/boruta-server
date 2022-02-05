defmodule BorutaIdentityWeb.UserSessionControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "whithout client set" do
    test "new session redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_session_path(conn, :new), %{"user" => %{}})
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end

    test "create session redirects to home", %{conn: conn} do
      conn = post(conn, Routes.user_session_path(conn, :create), %{"user" => %{}})
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end

    test "delete session redirects to home", %{conn: conn} do
      conn = delete(conn, Routes.user_session_path(conn, :delete), %{"user" => %{}})
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/log_in" do
    setup :with_a_request

    test "renders log in page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_session_path(conn, :new, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
    end

    test "redirects if already logged in", %{conn: conn, user: user, request: request} do
      conn = conn |> log_in(user) |> get(Routes.user_session_path(conn, :new, request: request))
      assert redirected_to(conn) == "/user_return_to"
    end
  end

  describe "POST /users/log_in" do
    setup :with_a_request

    test "logs the user in", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the user in with remember me", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_boruta_identity_web_user_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "logs the user in with return to", %{conn: conn, user: user, request: request} do
      conn =
        conn
        |> post(Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/user_return_to"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /users/log_out" do
    setup :with_a_request

    test "logs the user out", %{conn: conn, user: user, request: request} do
      conn = conn |> log_in(user) |> delete(Routes.user_session_path(conn, :delete, request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn, request: request} do
      conn = delete(conn, Routes.user_session_path(conn, :delete, request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
