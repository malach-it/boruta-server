defmodule BorutaFederation.TrustChainsTest do
  use BorutaFederation.DataCase

  import BorutaFederation.Factory
  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.Entity.Token
  alias BorutaFederation.TrustChains

  describe "generate_statement/1" do
    test "generates a statement" do
      entity = insert(:entity)

      assert {:ok, statement} = TrustChains.generate_statement(entity)
      assert statement

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
