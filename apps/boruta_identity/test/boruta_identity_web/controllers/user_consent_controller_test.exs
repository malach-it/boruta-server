defmodule BorutaIdentityWeb.UserConsentControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Repo

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

    test "redirects to after sign in path with the requested scope", %{
      conn: conn,
      request: request,
      requested_scope: scope
    } do
      conn =
        conn
        |> log_in(user_fixture())
        |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{
          "scopes" => [scope.name]
        })

      assert redirected_to(conn) == "/user_return_to"
    end

    test "only requested scopes are consented", %{
      conn: conn,
      request: request,
      client: client,
      requested_scope: scope
    } do
      user = user_fixture()

      conn
      |> log_in(user)
      |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{
        "scopes" => [scope.name, "unrequested:scope"]
      })

      assert %Consent{scopes: [requested_scope]} =
               Repo.get_by(Consent, user_id: user.id, client_id: client.id)

      assert requested_scope == scope.name
    end

    test "malformed scopes cannot create consent", %{
      conn: conn,
      request: request,
      client: client
    } do
      user = user_fixture()

      conn
      |> log_in(user)
      |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{
        "scopes" => "request:scope"
      })

      refute Repo.get_by(Consent, user_id: user.id, client_id: client.id)
    end

    test "consent for one client preserves another client's consent", %{
      conn: conn,
      request: request,
      requested_scope: scope
    } do
      user = user_fixture()
      other_client_id = Ecto.UUID.generate()

      other_consent =
        Repo.insert!(%Consent{
          user_id: user.id,
          client_id: other_client_id,
          scopes: ["other:scope"]
        })

      conn =
        conn
        |> log_in(user)
        |> post(Routes.user_consent_path(conn, :consent, %{request: request}), %{
          "scopes" => [scope.name]
        })

      assert redirected_to(conn) == "/user_return_to"

      assert %Consent{client_id: ^other_client_id, scopes: ["other:scope"]} =
               Repo.get(Consent, other_consent.id)
    end
  end
end
