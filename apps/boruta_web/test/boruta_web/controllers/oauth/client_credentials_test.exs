defmodule BorutaWeb.Oauth.ClientCredentialsTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "client_credentials grant" do
    setup %{conn: conn} do
      client = insert(:client)

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client}
    end

    test "returns an error with invalid query parameters", %{conn: conn} do
      conn = post(conn, "/oauth/token")

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request is not a valid OAuth request. Need a grant_type param."
             }
    end

    test "returns an error with an invalid grant type", %{conn: conn} do
      conn = post(conn, "/oauth/token", "grant_type=bad_grant_type")

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request body validation failed. #/grant_type do match required pattern /^(client_credentials|agent_credentials|password|agent_code|authorization_code|refresh_token)$/."
             }
    end

    test "returns an error with invalid body parameters", %{conn: conn} do
      conn = post(conn, "/oauth/token", "grant_type=client_credentials")

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request body validation failed. Required property client_id is missing at #."
             }
    end

    test "returns an error with invalid client_id", %{conn: conn} do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=client_credentials&client_id=666&client_secret=666"
        )

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request body validation failed. #/client_id do match required pattern /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/."
             }
    end

    test "returns an error with invalid client_id/secret couple", %{conn: conn} do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=client_credentials&client_id=6a2f41a3-c54c-fce8-32d2-0324e1c32e22&client_secret=666"
        )

      assert json_response(conn, 401) == %{
               "error" => "invalid_client",
               "error_description" => "Invalid client_id or client_secret."
             }
    end

    test "returns an error with invalid client_secret", %{conn: conn, client: client} do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=client_credentials&client_id=#{client.id}&client_secret=666"
        )

      assert json_response(conn, 401) == %{
               "error" => "invalid_client",
               "error_description" => "Invalid client_id or client_secret."
             }
    end

    test "returns a token response with valid client_id/client_secret", %{
      conn: conn,
      client: client
    } do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=client_credentials&client_id=#{client.id}&client_secret=#{client.secret}"
        )

      %{
        "access_token" => access_token,
        "token_type" => token_type,
        "expires_in" => expires_in,
        "refresh_token" => refresh_token
      } = json_response(conn, 200)

      assert access_token
      assert token_type == "bearer"
      assert expires_in
      assert refresh_token
    end

    test "returns a token response with valid agent token request", %{
      conn: conn,
      client: client
    } do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=agent_credentials&client_id=#{client.id}&client_secret=#{client.secret}&bind_data={}&bind_configuration={}"
        )

      %{
        "agent_token" => agent_token,
        "token_type" => token_type,
        "expires_in" => expires_in,
        "refresh_token" => refresh_token
      } = json_response(conn, 200)

      assert agent_token
      assert token_type == "bearer"
      assert expires_in
      assert refresh_token
    end
  end
end
