defmodule BorutaIdentityWeb.UserConsentControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  describe "GET /consent" do
    setup :with_a_request

    test "renders consent form", %{
      conn: conn,
      request: request,
      requested_scope: scope
    } do
      conn =
        conn
        |> log_in(user_fixture())
        |> get(Routes.user_consent_path(conn, :index, %{request: request}))

      assert html_response(conn, 200) =~ "Scope from request"
      assert html_response(conn, 200) =~ scope.name
    end
  end

  describe "POST /consent" do
    setup :with_a_request

    test "redirects to after sign in path with valid params", %{conn: conn, request: request} do
      conn =
        conn
        |> log_in(user_fixture())
        |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{})

      assert redirected_to(conn) == "/user_return_to"
    end
  end
end
