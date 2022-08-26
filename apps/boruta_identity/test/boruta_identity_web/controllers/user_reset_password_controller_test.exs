defmodule BorutaIdentityWeb.UserResetPasswordControllerTest do
  use BorutaIdentityWeb.ConnCase, async: false

  import BorutaIdentity.AccountsFixtures
  import Swoosh.TestAssertions

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Repo

  setup :set_swoosh_global
  setup :with_a_request

  setup %{identity_provider: identity_provider} do
    {:ok, user: user_fixture(%{backend: identity_provider.backend})}
  end

  describe "GET /users/reset_password" do
    test "renders the reset password page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_reset_password_path(conn, :new, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST /users/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "If your email is in our system"

      user_token = Repo.get_by!(Accounts.UserToken, user_id: user.id)
      assert user_token.context == "reset_password"
      assert_email_sent(text_body: ~r/reset your password/)
    end

    test "does not send reset password token if email is invalid", %{conn: conn, request: request} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create, request: request), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.UserToken) == []

      refute_email_sent()
    end
  end

  describe "GET /users/reset_password/:token" do
    setup %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end

      {:ok, token} =
        Deliveries.deliver_user_reset_password_instructions(user.backend, user, reset_password_url_fun)

      {:ok, token: token}
    end

    test "renders reset password", %{conn: conn, token: token, request: request} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, token, request: request))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, "oops", request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :error) =~ "Given reset password token is invalid."
    end
  end

  describe "PUT /users/reset_password/:token" do
    setup %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end

      {:ok, token} =
        Deliveries.deliver_user_reset_password_instructions(user.backend, user, reset_password_url_fun)

      {:ok, token: token}
    end

    test "resets password once", %{conn: conn, user: user, token: token, request: request, identity_provider: identity_provider} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token, request: request), %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert {:ok, user} = Accounts.Internal.get_user(identity_provider.backend, %{email: user.username})

      assert {:ok, _user} =
               Accounts.Internal.check_user_against(
                 identity_provider.backend,
                 user,
                 %{password: "new valid password"}
               )
    end

    test "does not reset password on invalid data", %{conn: conn, token: token, request: request} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token, request: request), %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Reset password</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
    end

    test "does not reset password with invalid token", %{conn: conn, request: request} do
      conn = put(conn, Routes.user_reset_password_path(conn, :update, "oops", request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :error) =~ "Given reset password token is invalid."
    end
  end
end
