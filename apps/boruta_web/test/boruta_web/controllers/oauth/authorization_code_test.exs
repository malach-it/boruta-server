defmodule BorutaWeb.Oauth.AuthorizationCodeTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.Oauth.Client
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Token
  alias Boruta.Openid.CredentialOfferResponse
  alias BorutaIdentityWeb.Authenticable
  alias BorutaWeb.Oauth.AuthorizeController

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
  end

  describe "authorization code grant" do
    setup %{conn: conn} do
      resource_owner = user_fixture()
      client = insert(:client)
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider, consentable: true)

      BorutaIdentity.Factory.insert(:client_identity_provider,
        client_id: client.id,
        identity_provider: identity_provider
      )

      scope = insert(:scope, public: true)

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client,
       resource_owner: resource_owner,
       scope: scope}
    end

    test "renders preauthorize with scope", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      scope: scope
    } do
      redirect_uri = List.first(client.redirect_uris)
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )
      )
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )

      assert redirected_to(conn) == IdentityRoutes.user_consent_path(conn, :index, request: request_param)
    end

    test "logs a pre-authorized code offer with the user id", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner
    } do
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

      code = %Token{
        type: "preauthorized_code",
        value: "preauthorized-code",
        expires_at: System.system_time(:second) + 60,
        client: %Client{id: client.id, enforce_tx_code: false},
        sub: resource_owner.id,
        resource_owner: %ResourceOwner{sub: resource_owner.id}
      }

      response = %CredentialOfferResponse{
        credential_issuer: Boruta.Config.issuer(),
        client_id: client.id,
        redirect_uri: "openid-credential-offer://",
        code: code
      }

      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> Map.put(:query_params, %{"client_id" => client.id})

      conn = AuthorizeController.authorize_success(conn, response)

      assert html_response(conn, 200)

      assert_received {
        [:authorization, :authorize, :success],
        %{},
        %{
          client_id: client_id,
          sub: sub,
          type: "preauthorized_code"
        }
      }

      assert client_id == client.id
      assert sub == resource_owner.id
    end

    test "redirects to redirect_uri with errors in query if redirect_uri is invalid", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      assert_raise BorutaWeb.AuthorizeError, "Invalid client_id or redirect_uri.", fn ->
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: "http://bad.redirect.uri",
            state: "state"
          })
        )
      end
    end

    test "redirects to redirect_uri with token if current_user is set", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner
    } do
      redirect_uri = List.first(client.redirect_uris)
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri
          })
        )
      )
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true, preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri
          })
        )

      [_, code] =
        Regex.run(
          ~r/#{redirect_uri}\?code=(.+)/,
          redirected_to(conn)
        )

      assert code
    end

    test "redirects to redirect_uri with state when session chosen", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner
    } do
      given_state = "state"
      redirect_uri = List.first(client.redirect_uris)
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: given_state
          })
        )
      )

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true, preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: given_state
          })
        )

      assert [_, _redirect_uri] =
        Regex.run(
          ~r/(#{redirect_uri})\?/,
          redirected_to(conn)
        )

      [_, code] =
        Regex.run(
          ~r/code=([^&]+)/,
          redirected_to(conn)
        )

      [_, state] =
        Regex.run(
          ~r/state=([^&]+)/,
          redirected_to(conn)
        )

      assert code
      assert state == given_state
    end

    test "redirects to redirect_uri with consented scope", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      scope: scope
    } do
      redirect_uri = List.first(client.redirect_uris)
      request_param =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )
        |> Authenticable.request_param()

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true, preauthorizations: %{request_param => true})

      BorutaIdentity.Factory.insert(:consent,
        user_id: resource_owner.id,
        client_id: client.id,
        scopes: [scope.name]
      )

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )

      [_, code] =
        Regex.run(
          ~r/#{redirect_uri}\?code=(.+)/,
          redirected_to(conn)
        )

      assert code
    end

    @tag :skip
    test "delivers a token inexchange of a code"

    @tag :skip
    test "preauthorize error case"
  end
end
