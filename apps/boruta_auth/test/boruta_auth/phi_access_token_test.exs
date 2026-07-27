defmodule BorutaAuth.PhiAccessTokenTest do
  use ExUnit.Case, async: true

  alias BorutaAuth.BlsKeyPair
  alias BorutaAuth.BlsSignature
  alias BorutaAuth.PhiAccessToken

  test "stores only the final state and verifies with private keys" do
    resource_owner = BlsKeyPair.generate()
    client = BlsKeyPair.generate()
    other_client = BlsKeyPair.generate()
    phi_data_token = "did:key:zPhiDataToken"

    assert {:ok, phi_access_token} =
             PhiAccessToken.issue(
               phi_data_token,
               resource_owner.private_key,
               client.private_key
             )

    assert PhiAccessToken.verify_with_private_keys(
             phi_access_token,
             phi_data_token,
             resource_owner.private_key,
             client.private_key
           )

    assert PhiAccessToken.verify_remaining(
             phi_access_token,
             phi_data_token,
             resource_owner.private_key,
             client.public_key
           )

    assert PhiAccessToken.verify_remaining(
             phi_access_token,
             phi_data_token,
             client.private_key,
             resource_owner.public_key
           )

    assert {:ok, resource_owner_key_proof} =
             PhiAccessToken.prove_remaining(phi_access_token, client.private_key)

    assert {:ok, client_key_proof} =
             PhiAccessToken.prove_remaining(phi_access_token, resource_owner.private_key)

    assert PhiAccessToken.verify_remaining_proof(
             phi_access_token,
             phi_data_token,
             client_key_proof,
             resource_owner.public_key,
             client.public_key
           )

    assert PhiAccessToken.verify_remaining_proof(
             phi_access_token,
             phi_data_token,
             resource_owner_key_proof,
             client.public_key,
             resource_owner.public_key
           )

    refute PhiAccessToken.verify_remaining_proof(
             phi_access_token,
             phi_data_token,
             resource_owner_key_proof,
             client.public_key,
             other_client.public_key
           )

    refute PhiAccessToken.verify_remaining_proof(
             phi_access_token,
             phi_data_token,
             resource_owner_key_proof,
             other_client.public_key,
             resource_owner.public_key
           )

    refute PhiAccessToken.verify_remaining(
             phi_access_token,
             phi_data_token,
             other_client.private_key,
             resource_owner.public_key
           )

    refute PhiAccessToken.verify_with_private_keys(
             phi_access_token,
             phi_data_token <> "changed",
             resource_owner.private_key,
             client.private_key
           )

    refute PhiAccessToken.verify_with_private_keys(
             phi_access_token,
             phi_data_token,
             resource_owner.private_key,
             other_client.private_key
           )

    assert {:ok, decoded} = Base.url_decode64(phi_access_token, padding: false)
    assert <<2, _final_state::binary-size(96)>> = decoded
  end

  test "rejects legacy group-added signatures" do
    resource_owner = BlsKeyPair.generate()
    client = BlsKeyPair.generate()
    phi_data_token = "did:key:zPhiDataToken"

    assert {:ok, resource_owner_signature} =
             BlsSignature.sign(resource_owner.private_key, phi_data_token)

    assert {:ok, client_signature} = BlsSignature.sign(client.private_key, phi_data_token)

    assert {:ok, aggregate_signature} =
             BlsSignature.aggregate([resource_owner_signature, client_signature])

    legacy_token = Base.url_encode64(aggregate_signature, padding: false)

    refute PhiAccessToken.verify_with_private_keys(
             legacy_token,
             phi_data_token,
             resource_owner.private_key,
             client.private_key
           )

    refute PhiAccessToken.verify_remaining(
             legacy_token,
             phi_data_token,
             resource_owner.private_key,
             client.public_key
           )
  end
end
