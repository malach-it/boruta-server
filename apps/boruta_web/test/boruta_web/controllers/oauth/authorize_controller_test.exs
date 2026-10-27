defmodule BorutaWeb.AuthorizeControllerTest do
  use BorutaWeb.ConnCase

  import BorutaWeb.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.ClientsAdapter
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token
  alias Boruta.Openid.SiopV2Response
  alias Boruta.Openid.VerifiablePresentationResponse
  alias BorutaIdentity.IdentityProviders
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
        |> log_in_for_client(resource_owner, client.id)

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
        |> log_in_for_client(resource_owner, client.id)
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

    test "use public client identity provider for second factor authentication", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      public_client_id = ClientsAdapter.public!().id

      identity_provider =
        BorutaIdentity.Factory.insert(:identity_provider,
          enforce_totp: true,
          totpable: true
        )

      {:ok, _} =
        IdentityProviders.upsert_client_identity_provider(public_client_id, identity_provider.id)

      on_exit(fn ->
        BorutaIdentity.Cache.delete(
          {IdentityProviders, :identity_provider_by_client_id, public_client_id}
        )
      end)

      conn =
        conn
        |> log_in_for_client(resource_owner, client.id)
        |> init_test_session(session_chosen: true)
        |> get(
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: "state"
          })
        )

      assert redirected_to(conn) =~ IdentityRoutes.user_session_path(conn, :initialize_totp)
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

  test "direct post authorization responses emit a business success event", %{conn: conn} do
    test_pid = self()
    handler_id = {__MODULE__, test_pid, make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:authorization, :authorize, :success],
        fn event, measurements, metadata, _config ->
          send(test_pid, {event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    client = insert(:client) |> then(&ClientsAdapter.get_client(&1.id))

    code = %Token{
      id: "code-id",
      type: "preauthorized_code",
      client: client,
      sub: "did:key:owner",
      scope: "openid",
      expires_at: System.system_time(:second) + 60
    }

    response_params = %{
      client_id: "did:key:owner",
      code: code,
      scope: code.scope,
      redirect_uri: "https://wallet.example/callback",
      issuer: Boruta.Config.issuer(),
      client: client,
      response_mode: "direct_post",
      nonce: "nonce"
    }

    responses = [
      struct!(SiopV2Response, response_params),
      struct!(
        VerifiablePresentationResponse,
        Map.put(response_params, :presentation_definition, %{})
      )
    ]

    for response <- responses do
      conn = conn |> init_test_session(%{}) |> AuthorizeController.authorize_success(response)

      redirect_uri =
        redirected_to(conn) |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert redirect_uri["redirect_uri"] =~ "/openid/direct_post/code-id"

      assert_receive {
        [:authorization, :authorize, :success],
        %{},
        %{
          type: "preauthorized_code",
          response_mode: "direct_post",
          client_id: client_id,
          sub: "did:key:owner",
          scope: "openid",
          expires_in: expires_in
        }
      }

      assert client_id == client.id
      assert expires_in in 0..60
    end
  end
end
