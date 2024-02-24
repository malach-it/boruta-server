defmodule BorutaWeb.Integration.DirectPostTest do
  use BorutaWeb.ConnCase, async: false

  alias Boruta.Oauth.Client
  alias Boruta.Ecto.OauthMapper

  setup %{conn: conn} do
    client = Boruta.Factory.insert(:client, id_token_signature_alg: "RS512")
    code = Boruta.Factory.insert(:token, type: "code", redirect_uri: "http://redirect.uri", state: "state")

    {:ok,
      client: client,
      code: code,
      conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded")}
  end

  describe "SIOPV2 direct post" do
    test "unauthorized with a bad id_token", %{conn: conn} do
      conn =
        post(
          conn,
          "/openid/direct_post/bad_code",
          "id_token=bad_id_token"
        )

      assert json_response(conn, 401) == %{
               "error" => "unauthorized",
               "error_description" => ":token_malformed"
             }
    end

    test "not found with a bad code", %{client: client, conn: conn} do
      payload = %{}
      conn =
        post(
          conn,
          "/openid/direct_post/bad_code",
          "id_token=#{Client.Crypto.id_token_sign(payload, OauthMapper.to_oauth_schema(client))}"
        )

      assert response(conn, 404)
    end

    test "authenticated", %{client: client, code: code, conn: conn} do
      payload = %{}
      conn =
        post(
          conn,
          "/openid/direct_post/#{code.id}",
          "id_token=#{Client.Crypto.id_token_sign(payload, OauthMapper.to_oauth_schema(client))}"
        )

      assert redirected_to(conn) =~ ~r/#{code.redirect_uri}/
      assert redirected_to(conn) =~ ~r/code=#{code.value}/
    end
  end
end
