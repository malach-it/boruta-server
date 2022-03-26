defmodule BorutaIdentityWeb.UserConsentControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  describe "GET /consent" do
    setup :with_a_request

    test "", %{conn: conn, request: request, client: client} do
      conn = conn
             |> log_in(user_fixture())
             |> get(Routes.user_consent_path(conn, :index, %{request: request}))

      assert html_response(conn, 200) =~ "Scope from request"
      assert html_response(conn, 200) =~ client.id
    end
  end

  describe "POST /consent" do
    setup :with_a_request

    test "render 422 with invalid params", %{conn: conn, request: request} do
      conn = conn
             |> log_in(user_fixture())
             |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{})

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, %{request: request})
      assert get_flash(conn, :error) |> Phoenix.HTML.safe_to_string() =~ ~r/client_id/
    end

    test "redirects to after sign in path with valid params", %{conn: conn, client: client} do
      conn = conn
             |> log_in(user_fixture())
             |> post(Routes.user_consent_path(conn, :consent), %{client_id: client.id, scopes: ["test"]})

      assert redirected_to(conn) == "/"
    end
  end
end
