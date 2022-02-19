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

    test "redirects to choose session if session not chosen", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn = conn
             |> log_in(resource_owner)

      conn = get(
        conn,
        Routes.authorize_path(conn, :authorize, %{
          response_type: "token",
          client_id: client.id,
          redirect_uri: redirect_uri,
          state: "state"
        })
      )

      assert html_response(conn, 200) =~ ~r/choose-session/
    end
  end
end
