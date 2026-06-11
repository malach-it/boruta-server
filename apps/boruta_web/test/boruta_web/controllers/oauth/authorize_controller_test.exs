defmodule BorutaWeb.AuthorizeControllerTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.Oauth.Error
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
