defmodule BorutaWeb.Oauth.AuthorizationCodeTest do
  use BorutaWeb.ConnCase, async: true

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts

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

    test "stores oauth request params in session when current_user is not set", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      oauth_url =
        Routes.authorize_path(conn, :authorize, %{
          response_type: "token",
          client_id: client.id,
          redirect_uri: redirect_uri,
          code_challenge: "code challenge",
          state: "state",
          scope: "scope"
        })

      conn = get(conn, oauth_url)

      assert get_session(conn, :user_return_to) |> URI.parse() == URI.parse(oauth_url)
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

      assert redirected_to(conn) == Routes.choose_session_path(conn, :new)
    end
  end

  describe "authorization code grant" do
    # TODO est token delivrance with code
    setup %{conn: conn} do
      resource_owner = user_fixture()
      client = insert(:client)
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

      [_, error, error_description] =
        Regex.run(
          ~r/error=(.+)&error_description=(.+)/,
          redirected_to(conn)
        )

      assert error
      assert error_description
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

      assert html_response(conn, 200) =~ ~r/#{scope.name}/
      assert html_response(conn, 200) =~ ~r/Consent/
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
      Accounts.consent(resource_owner, %{client_id: client.id, scopes: [scope.name]})

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
