defmodule BorutaFederationWeb.ResolveControllerTest do
  use BorutaFederationWeb.ConnCase

  import BorutaFederation.Factory
  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.LeafEntity.Token

  describe "GET /resolve" do
    test "retruns not found", %{conn: conn} do
      conn = get(conn, Routes.resolve_path(conn, :resolve, %{sub: "sub", anchor: "anchor"}))
      assert json_response(conn, 404) == %{
        "error" => "not_found",
        "error_description" => "Federation entity could not be found."
      }
    end

    test "retruns a statement", %{conn: conn} do
      entity = insert(:entity)

      conn = get(conn, Routes.resolve_path(conn, :resolve, %{sub: entity.id, anchor: "anchor"}))
      assert statement = response(conn, 200)

      sub = issuer() <> "/federation/federation_entities/#{entity.id}"

      assert {:ok,
              %{
                "exp" => exp,
                "iat" => iat,
                "iss" => "http://localhost:4000",
                "jwks" => %{"keys" => [jwk]},
                "metadata" => %{"openid_provider" => %{"issuer" => "http://localhost:4000"}},
                "sub" => ^sub,
                "trust_marks" => [trust_mark]
              }} = Joken.peek_claims(statement)

      signer =
        Joken.Signer.create(entity.trust_chain_statement_alg, %{
          "pem" => JOSE.JWK.from_map(jwk) |> JOSE.JWK.to_pem() |> elem(1)
        })

      assert {:ok, _} = Token.verify_and_validate(statement, signer)
      assert {:ok, _} = Token.verify_and_validate(trust_mark, signer)
      assert iat
      assert exp
    end
  end
end
