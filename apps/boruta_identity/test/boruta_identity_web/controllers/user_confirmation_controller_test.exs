defmodule BorutaIdentityWeb.UserConfirmationControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Repo

  import BorutaIdentity.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "whithout client set" do
    test "new confirmation redirects to log in", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end

    test "create confirmation redirects to home", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.user_confirmation_path(conn, :create, %{
            "user" => %{"email" => "user@email.test"}
          })
        )

      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "whithout client confirmable configuration enabled" do
    setup :with_a_request

    setup %{relying_party: relying_party} do
      relying_party
      |> Ecto.Changeset.change(confirmable: false)
      |> Repo.update()

      {:ok, relying_party: relying_party}
    end

    test "new confirmation redirects to home", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new, request: request))

      assert get_flash(conn, :error) ==
               "Feature is not enabled for client relying party."

      assert redirected_to(conn) == "/"
    end

    test "create confirmation redirects to home", %{conn: conn, request: request} do
      conn =
        post(
          conn,
          Routes.user_confirmation_path(conn, :create, %{
            "user" => %{"email" => "user@email.test"},
            request: request
          })
        )

      assert get_flash(conn, :error) ==
               "Feature is not enabled for client relying party."

      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/confirm" do
    setup :with_a_request

    test "renders the confirmation page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /users/confirm" do
    setup :with_a_request

    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{
      conn: conn,
      request: request
    } do
      {:ok, user} = user_fixture() |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now()) |> Repo.update()

      conn =
        post(conn, Routes.user_confirmation_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn, request: request} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create, request: request), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/confirm/:token" do
    setup :with_a_request

    test "confirms the given token once", %{conn: conn, user: user, request: request} do
      confirmation_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Deliveries.deliver_user_confirmation_instructions(user, confirmation_url_fun)

      confirm_conn =
        get(conn, Routes.user_confirmation_path(conn, :confirm, token, request: request))

      assert redirected_to(confirm_conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(confirm_conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_user(user.id).confirmed_at
      refute get_session(confirm_conn, :user_token)

      # When not logged in
      signed_out_conn =
        get(conn, Routes.user_confirmation_path(conn, :confirm, token, request: request))

      assert redirected_to(signed_out_conn) ==
               Routes.user_session_path(signed_out_conn, :new, request: request)

      assert get_flash(signed_out_conn, :error) =~
               "Account confirmation token is invalid or it has expired"
    end

    test "redirects if user is already confirmed", %{conn: conn, request: request} do
      user_fixture() |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now()) |> Repo.update()

      signed_in_conn =
        conn
        |> get(Routes.user_confirmation_path(conn, :confirm, "unused_token", request: request))

      assert redirected_to(signed_in_conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(signed_in_conn, :error) =~ "Account confirmation token is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user, request: request} do
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, "oops", request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :error) =~ "Account confirmation token is invalid or it has expired"
      refute Accounts.get_user(user.id).confirmed_at
    end
  end
end
