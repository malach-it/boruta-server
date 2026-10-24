defmodule BorutaIdentityWeb.UserConsentControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.IdentityProviders
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

    test "stateful consent form binds its POST to the displayed request", %{
      conn: conn,
      request: request,
      identity_provider: identity_provider,
      client: client,
      requested_scope: scope
    } do
      {:ok, _identity_provider} =
        IdentityProviders.update_identity_provider(identity_provider, %{request_mode: "stateful"})

      user = user_fixture()
      request_id = "first-request"
      stored_request = %{"id" => request_id, "jwt" => request}

      form_conn =
        conn
        |> log_in(user)
        |> put_session(:authorization_request, stored_request)
        |> get(Routes.user_consent_path(conn, :index))

      assert html_response(form_conn, 200) =~ "request=#{request_id}"

      valid_conn =
        build_conn()
        |> log_in(user)
        |> put_session(:authorization_request, stored_request)
        |> post(Routes.user_consent_path(conn, :consent, request: request_id), %{
          "scopes" => [scope.name]
        })

      assert redirected_to(valid_conn) == "/user_return_to"

      assert %Consent{scopes: [consented_scope]} =
               Repo.get_by(Consent, user_id: user.id, client_id: client.id)

      assert consented_scope == scope.name

      missing_request_conn =
        build_conn()
        |> log_in(user)
        |> put_session(:authorization_request, stored_request)
        |> post(Routes.user_consent_path(conn, :consent), %{"scopes" => [scope.name]})

      assert response(missing_request_conn, 409) =~ "Authorization request changed"
    end

    test "stale stateful consent form cannot grant another client's scopes", %{
      conn: conn,
      identity_provider: identity_provider,
      client: client,
      requested_scope: scope
    } do
      {:ok, _identity_provider} =
        IdentityProviders.update_identity_provider(identity_provider, %{request_mode: "stateful"})

      user = user_fixture()
      other_client = Boruta.Factory.insert(:client)

      BorutaIdentity.Factory.insert(:client_identity_provider,
        client_id: other_client.id,
        identity_provider: identity_provider
      )

      {:ok, other_request, _payload} =
        Joken.encode_and_sign(
          %{
            "client_id" => other_client.id,
            "scope" => scope.name,
            "user_return_to" => "/other_return_to"
          },
          BorutaIdentityWeb.Token.application_signer()
        )

      stale_request_id = "first-request"

      conn =
        conn
        |> log_in(user)
        |> put_session(:authorization_request, %{"id" => "second-request", "jwt" => other_request})
        |> post(Routes.user_consent_path(conn, :consent, request: stale_request_id), %{
          "scopes" => [scope.name]
        })

      assert response(conn, 409) =~ "Authorization request changed"
      refute Repo.get_by(Consent, user_id: user.id, client_id: other_client.id)
      refute Repo.get_by(Consent, user_id: user.id, client_id: client.id)
    end

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
