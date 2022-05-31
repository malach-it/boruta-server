defmodule BorutaIdentityWeb.UserSettingsControllerTest do
  use BorutaIdentityWeb.ConnCase

  setup :register_and_log_in

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
