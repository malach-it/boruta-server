defmodule BorutaIdentityWeb.UserSessionControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "whithout client set" do
    test "create session redirects to home", %{conn: conn} do
      conn = post(conn, Routes.user_session_path(conn, :create), %{"user" => %{}})
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "whithout client relying party" do
    setup %{conn: conn} do
      conn = init_test_session(conn, %{current_client_id: SecureRandom.uuid()})

      {:ok, conn: conn}
    end

    test "create session redirects to home", %{conn: conn} do
      conn = post(conn, Routes.user_session_path(conn, :create), %{"user" => %{}})
      assert get_flash(conn, :error) == "Relying Party not configured for given OAuth client. Please contact your administrator."
      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/log_in" do
    setup %{conn: conn} do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.user_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in(user) |> get(Routes.user_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /users/log_in" do
    setup %{conn: conn} do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
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

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_boruta_identity_web_user_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /users/log_out" do
    setup %{conn: conn} do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in(user) |> delete(Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
