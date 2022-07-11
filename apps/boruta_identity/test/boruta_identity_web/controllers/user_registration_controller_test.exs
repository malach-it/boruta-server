defmodule BorutaIdentityWeb.UserRegistrationControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Repo

  describe "GET /users/register" do
    setup :with_a_request

    test "renders registration page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_registration_path(conn, :new, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
    end

    test "redirects if already logged in", %{conn: conn, request: request} do
      conn =
        conn
        |> log_in(user_fixture())
        |> get(Routes.user_registration_path(conn, :new, request: request))

      assert redirected_to(conn) == "/user_return_to"
    end
  end

  describe "POST /users/register" do
    setup :with_a_request

    @tag :capture_log
    test "creates account and ask for confirmation in if confirmable", %{conn: conn, request: request} do
      email = unique_user_email()

      conn =
        post(conn, Routes.user_registration_path(conn, :create, request: request), %{
          "user" => %{"email" => email, "password" => valid_user_password()}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
      assert response =~ "Email confirmation is required to authenticate."
    end

    @tag :capture_log
    test "creates account and logs the user in if not confirmable", %{identity_provider: identity_provider, conn: conn, request: request} do
      Ecto.Changeset.change(identity_provider, confirmable: false) |> Repo.update()
      email = unique_user_email()

      conn =
        post(conn, Routes.user_registration_path(conn, :create, request: request), %{
          "user" => %{"email" => email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) =~ "/user_return_to"
    end

    test "render errors for invalid data", %{conn: conn, request: request} do
      conn =
        post(conn, Routes.user_registration_path(conn, :create, request: request), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
