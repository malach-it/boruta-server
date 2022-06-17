defmodule BorutaWeb.Oauth.ImplicitTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "implicit grant" do
    setup %{conn: conn} do
      resource_owner = user_fixture()
      redirect_uri = "http://redirect.uri"
      client = insert(:client, redirect_uris: [redirect_uri])
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider, consentable: true)
      BorutaIdentity.Factory.insert(:client_identity_provider, client_id: client.id, identity_provider: identity_provider)
      scope = insert(:scope, public: true)

      {:ok,
       conn: conn,
       client: client,
       redirect_uri: redirect_uri,
       resource_owner: resource_owner,
       scope: scope}
    end

    # TODO test different validation cases
    test "validates request params", %{
      conn: conn,
      resource_owner: resource_owner
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn = get(conn, "/oauth/authorize")

      assert response_content_type(conn, :html)

      assert response(conn, 400) =~
               "Request is not a valid OAuth request. Need a response_type param."
    end

    test "returns an error if client_id is invalid", %{
      conn: conn,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            redirect_uri: redirect_uri,
            state: "state"
          })
        )

      assert html_response(conn, 401) =~ ~r/Invalid client_id or redirect_uri./
    end

    test "redirect to user authentication page", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri
          })
        )

      # NOTE Path will be scoped in production with configuration and be forwarded to
      assert redirected_to(conn) =~ "/users/log_in"
    end

    test "redirects to redirect_uri with token if current_user is set", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
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
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri
          })
        )

      [_, access_token, expires_in] =
        Regex.run(
          ~r/#{redirect_uri}#access_token=(.+)&expires_in=(.+)/,
          redirected_to(conn)
        )

      assert access_token
      assert expires_in
    end

    test "redirects to redirect_uri with state", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      given_state = "state"
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
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
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            state: given_state
          })
        )

      [_, access_token, expires_in, state] =
        Regex.run(
          ~r/#{redirect_uri}#access_token=(.+)&expires_in=(.+)&state=(.+)&token_type=bearer/,
          redirected_to(conn)
        )

      assert access_token
      assert expires_in
      assert state == given_state
    end

    test "renders preauthorize with scope", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner,
      scope: scope
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )

      # TODO test request query param
      assert redirected_to(conn) =~ IdentityRoutes.user_consent_path(conn, :index)
    end

    test "redirects to redirect_uri with consented scope", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner,
      scope: scope
    } do
      request_param = Authenticable.request_param(
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )
      )
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
            response_type: "token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: scope.name
          })
        )

      [_, access_token, expires_in] =
        Regex.run(
          ~r/#{redirect_uri}#access_token=(.+)&expires_in=(.+)/,
          redirected_to(conn)
        )

      assert access_token
      assert expires_in
    end

    @tag :skip
    test "preauthorize error case"
  end
end
