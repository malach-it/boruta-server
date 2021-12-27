defmodule BorutaIdentityWeb.UserResetPasswordControllerTest do
  use BorutaIdentityWeb.ConnCase, async: false

  import BorutaIdentity.AccountsFixtures
  import Swoosh.TestAssertions

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Repo

  setup :set_swoosh_global

  setup do
    %{user: user_fixture()}
  end

  describe "GET /users/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.user_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST /users/reset_password" do
    setup %{conn: conn} do
      client_relying_party = BorutaIdentity.Factory.insert(:client_relying_party)

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your email is in our system"

      user_token = Repo.get_by!(Accounts.UserToken, user_id: user.id)
      assert user_token.context == "reset_password"
      assert_email_sent([text_body: ~r/reset your password/])
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.user_reset_password_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.UserToken) == []

      refute_email_sent()
    end
  end

  describe "GET /users/reset_password/:token" do
    setup %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Accounts.deliver_user_reset_password_instructions(user, reset_password_url_fun)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.user_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /users/reset_password/:token" do
    setup %{user: user} do
      reset_password_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Accounts.deliver_user_reset_password_instructions(user, reset_password_url_fun)

      %{token: token}
    end

    test "resets password once", %{conn: conn, user: user, token: token} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token), %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert user = Accounts.get_user_by_email(user.email)
      assert :ok = Accounts.check_user_password(user, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.user_reset_password_path(conn, :update, token), %{
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

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.user_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
