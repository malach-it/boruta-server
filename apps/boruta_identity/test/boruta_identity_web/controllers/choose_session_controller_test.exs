defmodule BorutaIdentityWeb.ChooseSessionControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.Repo

  describe "GET /choose_session" do
    setup :with_a_request

    test "renders choose session template", %{conn: conn, request: request} do
      conn =
        conn
        |> log_in(user_fixture())
        |> get(Routes.choose_session_path(conn, :index, %{request: request}))

      assert html_response(conn, 200) =~ "Continue ?"
      refute get_session(conn, :session_chosen)
    end

    test "includes the stateful request in logout links", %{
      conn: conn,
      request: request,
      identity_provider: identity_provider
    } do
      {:ok, _identity_provider} =
        IdentityProviders.update_identity_provider(identity_provider, %{request_mode: "stateful"})

      request_id = "first-request"

      conn =
        conn
        |> log_in(user_fixture())
        |> put_session(:authorization_request, %{"id" => request_id, "jwt" => request})
        |> get(Routes.choose_session_path(conn, :index))

      assert html_response(conn, 200) =~
               Routes.user_session_path(conn, :delete, request: request_id)
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
