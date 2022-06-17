defmodule BorutaIdentityWeb.ChooseSessionControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Repo

  describe "GET /choose_session" do
    setup :with_a_request

    test "renders choose session template", %{conn: conn, request: request} do
      conn =
        conn
        |> log_in(user_fixture())
        |> get(Routes.choose_session_path(conn, :index, %{request: request}))

      assert html_response(conn, 200) =~ "Continue ?"
    end

    test "redirect to log in if identity provider disabled choose_session", %{
      conn: conn,
      identity_provider: identity_provider,
      request: request
    } do
      identity_provider |> Ecto.Changeset.change(choose_session: false) |> Repo.update()
      conn =
        conn
        |> log_in(user_fixture())
        |> get(Routes.choose_session_path(conn, :index, %{request: request}))

      assert redirected_to(conn) =~ Routes.user_session_path(conn, :new, request: request)
    end
  end
end
