defmodule BorutaIdentityWeb.UserSettingsControllerTest do
  use BorutaIdentityWeb.ConnCase

  alias BorutaIdentity.Accounts
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Repo

  setup :register_and_log_in

  describe "whithout client set" do
    test "edit user redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "with user_editable feature disabled" do
    setup :with_a_request

    setup %{relying_party: relying_party} do
      relying_party = relying_party
      |> Ecto.Changeset.change(user_editable: false)
      |> Repo.update()

      {:ok, relying_party: relying_party}
    end

    test "edit user redirects to home", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_settings_path(conn, :edit, request: request))
      assert get_flash(conn, :error) == "Feature is not enabled for client relying party."
      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/settings" do
    setup :with_a_request

    test "renders settings page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_settings_path(conn, :edit, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Edit user</h1>"
    end

    test "redirects if user is not logged in", %{request: request} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :edit, request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
    end
  end

  @tag :skip
  test "PUT /users/settings"

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end
  end
end
