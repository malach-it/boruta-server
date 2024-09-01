defmodule BorutaWeb.Oauth.PushedAuthorizationRequestControllerTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "pushed authorization request" do
    test "respond with an error", %{conn: conn} do
      request_params = %{}

      conn =
        post(
          conn,
          Routes.pushed_authorization_request_path(conn, :pushed_authorization_request),
          request_params
        )

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request is not a valid OAuth request. Need a response_type param."
             }
    end

    test "stores the request", %{conn: conn} do
      client = insert(:client, redirect_uris: ["http://redirect_uri"])

      request_params = %{
        "response_type" => "code",
        "client_id" => client.id,
        "redirect_uri" => List.first(client.redirect_uris)
      }

      conn =
        post(
          conn,
          Routes.pushed_authorization_request_path(conn, :pushed_authorization_request),
          request_params
        )

      assert %{
               "request_uri" => request_uri,
               "expires_in" => expires_in
             } = json_response(conn, 201)

      assert request_uri
      assert expires_in
    end
  end
end
