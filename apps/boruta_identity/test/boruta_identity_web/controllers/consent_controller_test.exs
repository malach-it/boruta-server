defmodule BorutaIdentityWeb.ConsentControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  describe "POST /consent" do
    test "render 422 with invalid params", %{conn: conn} do
      conn = conn
             |> log_in(user_fixture())
             |> post(Routes.consent_path(conn, :consent), %{})

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) |> Phoenix.HTML.safe_to_string() =~ ~r/client_id/
    end

    test "redirects to after sign in path with valid params", %{conn: conn} do
      conn = conn
             |> log_in(user_fixture())
             |> post(Routes.consent_path(conn, :consent), %{client_id: "client_id", scopes: ["test"]})

      assert redirected_to(conn) == "/"
    end
  end
end
