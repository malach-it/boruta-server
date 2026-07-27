defmodule BorutaIdentity.Accounts.BlsKeyPairTest do
  use ExUnit.Case, async: true

  alias BorutaAuth.BlsKeyPair
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend

  @generator_public_key Base.decode16!(
                          "97F1D3A73197D7942695638C4FA9AC0F" <>
                            "C3688C4F9774B905A14E3A3F171BAC5" <>
                            "86C55E83FF97A1AEFFB3AF00ADB22C6BB"
                        )
  @generator_did_key "did:key:z3tEFUdV4D3tCMG6Fr1deVvt32DCS1Y4SxDGoELedXaMUdTdr5FfZvBnbK9bWMhAGj3RHk"

  test "generates a persisted BLS12-381 key pair" do
    assert %{
             private_key: <<_::binary-size(32)>>,
             public_key: <<_::binary-size(48)>> = public_key,
             did_key: "did:key:z" <> _
           } = BlsKeyPair.generate()

    assert BlsKeyPair.did_key(public_key) =~ "did:key:z"
  end

  test "encodes the same did:key as phi-crypto" do
    assert BlsKeyPair.did_key(@generator_public_key) == @generator_did_key
  end

  test "computes a deterministic token commitment from the attribute key and value" do
    assert {:ok, "did:key:z" <> _} =
             token = BlsKeyPair.phi_data_token(@generator_public_key, "age", 7)

    assert BlsKeyPair.phi_data_token(@generator_public_key, "age", 7) == token
    refute BlsKeyPair.phi_data_token(@generator_public_key, "years", 7) == token
    refute BlsKeyPair.phi_data_token(@generator_public_key, "age", 8) == token
  end

  test "canonicalizes nested JSON object keys before committing" do
    assert BlsKeyPair.phi_data_token(
             @generator_public_key,
             "profile",
             %{"name" => "Ada", "roles" => ["admin"], "active" => true}
           ) ==
             BlsKeyPair.phi_data_token(
               @generator_public_key,
               "profile",
               %{"active" => true, "roles" => ["admin"], "name" => "Ada"}
             )
  end

  test "verifies a phi data token against its user key and committed attribute" do
    {:ok, token} = BlsKeyPair.phi_data_token(@generator_public_key, "age", 7)
    other_public_key = BlsKeyPair.generate().public_key

    assert BlsKeyPair.verify_phi_data_token(@generator_public_key, "age", 7, token)
    refute BlsKeyPair.verify_phi_data_token(@generator_public_key, "years", 7, token)
    refute BlsKeyPair.verify_phi_data_token(@generator_public_key, "age", 8, token)
    refute BlsKeyPair.verify_phi_data_token(other_public_key, "age", 7, token)
    refute BlsKeyPair.verify_phi_data_token(@generator_public_key, "age", 7, "did:key:invalid")
  end

  test "adds the phi data token to configured user metadata" do
    backend = %Backend{
      metadata_fields: [
        %{"attribute_name" => "age", "user_editable" => true, "phi_data_token" => true}
      ]
    }

    user = %User{
      backend: backend,
      bls_private_key: <<1::unsigned-big-integer-size(256)>>,
      bls_public_key: @generator_public_key,
      bls_did_key: @generator_did_key
    }

    metadata = %{
      "age" => %{"value" => 7, "status" => "valid", "display" => []}
    }

    {:ok, phi_data_token} =
      BlsKeyPair.phi_data_token(@generator_public_key, "age", 7)

    assert %User{
             metadata: %{
               "age" => %{
                 "value" => 7,
                 "status" => "valid",
                 "display" => [],
                 "phi_data_token" => ^phi_data_token
               }
             }
           } =
             user
             |> User.changeset(%{metadata: metadata})
             |> Ecto.Changeset.apply_changes()
  end
end
