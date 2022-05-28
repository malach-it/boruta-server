defmodule BorutaIdentityWeb.UserSettingsControllerTest do
  use BorutaIdentityWeb.ConnCase

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
end
