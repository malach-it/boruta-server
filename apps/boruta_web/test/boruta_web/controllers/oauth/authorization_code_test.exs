defmodule BorutaWeb.Oauth.AuthorizationCodeTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable

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
