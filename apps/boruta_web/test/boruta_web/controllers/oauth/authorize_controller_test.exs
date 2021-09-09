defmodule BorutaWeb.AuthorizeControllerTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

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
      conn = conn
             |> log_in(resource_owner)

      conn = get(
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
end
