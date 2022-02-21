defmodule BorutaIdentityWeb.ChooseSessionControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  describe "GET /choose_session" do
    setup :with_a_request

    test "renders choose session template", %{conn: conn, request: request} do
      conn = conn
             |> log_in(user_fixture())
             |> get(Routes.choose_session_path(conn, :index, %{request: request}))

      assert html_response(conn, 200) =~ "Continue ?"
    end
  end
end
