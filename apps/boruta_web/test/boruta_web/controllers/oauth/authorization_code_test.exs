defmodule BorutaWeb.Oauth.AuthorizationCodeTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

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
            client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            redirect_uri: redirect_uri,
            state: "state"
          })
        )

      assert html_response(conn, 200) =~ ~r/choose-session/
    end
  end

  describe "authorization code grant" do
    # TODO test token delivrance with code
    setup %{conn: conn} do
      resource_owner = user_fixture()
      client = insert(:client)
      BorutaIdentity.Factory.insert(:client_relying_party, client_id: client.id)
      scope = insert(:scope, public: true)

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client,
       resource_owner: resource_owner,
       scope: scope}
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

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: client.id,
            redirect_uri: "http://bad.redirect.uri",
            state: "state"
          })
        )

      assert html_response(conn, 401) =~ "Invalid client"
    end

    test "redirects to redirect_uri with token if current_user is set", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      redirect_uri = List.first(client.redirect_uris)

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
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      given_state = "state"
      redirect_uri = List.first(client.redirect_uris)

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

      [_, code, state] =
        Regex.run(
          ~r/#{redirect_uri}\?code=(.+)&state=(.+)/,
          redirected_to(conn)
        )

      assert code
      assert state == given_state
    end

    test "renders preauthorize with scope", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      scope: scope
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      redirect_uri = List.first(client.redirect_uris)

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

      # TODO test request query param
      assert redirected_to(conn) =~ IdentityRoutes.consent_path(conn, :index)
    end

    test "redirects to redirect_uri with consented scope", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      scope: scope
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      redirect_uri = List.first(client.redirect_uris)

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
  end
end
