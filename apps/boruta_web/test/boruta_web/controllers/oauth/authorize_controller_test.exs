defmodule BorutaWeb.AuthorizeControllerTest do
  use BorutaWeb.ConnCase

  import BorutaWeb.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.Oauth.Error
  alias BorutaIdentity.Repo
  alias BorutaWeb.Oauth.AuthorizeController

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "#authorize" do
    setup %{conn: conn} do
      resource_owner = user_fixture()
      redirect_uri = "http://redirect.uri"
      client = insert(:client, redirect_uris: [redirect_uri])

      {:ok,
       conn: conn, client: client, redirect_uri: redirect_uri, resource_owner: resource_owner}
    end

    test "redirects to choose session if session not chosen", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn =
        conn
        |> log_in(resource_owner)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: "state"
          })
        )

      assert redirected_to(conn) =~ IdentityRoutes.choose_session_path(conn, :index)
    end

    test "requires WebAuthn for a user with a registered credential and no TOTP", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      identity_provider =
        BorutaIdentity.Factory.insert(:identity_provider,
          webauthnable: true,
          enforce_webauthn: false,
          enforce_totp: false
        )

      BorutaIdentity.Factory.insert(:client_identity_provider,
        client_id: client.id,
        identity_provider: identity_provider
      )

      resource_owner =
        resource_owner
        |> Ecto.Changeset.change(webauthn_registered_at: DateTime.utc_now())
        |> Repo.update!()

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)
        |> get(
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: "state"
          })
        )

      assert redirected_to(conn) =~
               IdentityRoutes.user_session_path(conn, :initialize_webauthn)
    end

    @tag :skip
    test "error renders and redirections"

    test "clears mfa session state on formatted authorize errors", %{conn: conn} do
      conn =
        conn
        |> init_test_session(
          session_chosen: true,
          totp_authenticated: %{"token" => true},
          webauthn_authenticated: %{"token" => true}
        )
        |> Map.put(:query_params, %{"client_id" => "client_id"})

      conn =
        AuthorizeController.authorize_error(conn, %Error{
          status: :unauthorized,
          error: :invalid_request,
          error_description: "Invalid request.",
          format: :fragment,
          redirect_uri: "http://redirect.uri"
        })

      refute get_session(conn, :session_chosen)
      refute get_session(conn, :totp_authenticated)
      refute get_session(conn, :webauthn_authenticated)
    end
  end
end
