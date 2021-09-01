defmodule BorutaWeb.Oauth.PasswordTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "password grant" do
    setup %{conn: conn} do
      password = valid_user_password()
      resource_owner = user_fixture(password: password)
      client = insert(:client)

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client,
       resource_owner: resource_owner,
       password: password}
    end

    test "returns a token response with valid client_id/client_secret", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      password: password
    } do
      conn =
        post(
          conn,
          "/oauth/token",
          "grant_type=password&username=#{resource_owner.email}&password=#{password}&client_id=#{
            client.id
          }&client_secret=#{client.secret}"
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
  end
end
