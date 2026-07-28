defmodule BorutaAuth.PhiAccessToken do
  @moduledoc """
  Produces and verifies a sequential scalar accumulator of a phi data token.

  Version 2 tokens retain only the final client state. Verifying the remaining
  party therefore requires one participant's private key.
  """

  alias BorutaAuth.BlsSignature

  @version 2
  @remaining_proof_version 1
  @signature_size 96

  @spec issue(String.t(), binary(), binary()) :: {:ok, String.t()} | {:error, String.t()}
  def issue(phi_data_token, resource_owner_private_key, client_private_key)
      when is_binary(phi_data_token) do
    with {:ok, base} <- BlsSignature.base(phi_data_token),
         {:ok, resource_owner_state} <-
           BlsSignature.scale(base, resource_owner_private_key),
         {:ok, final_state} <- BlsSignature.scale(resource_owner_state, client_private_key) do
      {:ok, encode(final_state)}
    end
  end

  @doc """
  Reproduces the final state with both private keys.
  """
  @spec verify_with_private_keys(String.t(), String.t(), binary(), binary()) :: boolean()
  def verify_with_private_keys(
        phi_access_token,
        phi_data_token,
        resource_owner_private_key,
        client_private_key
      )
      when is_binary(phi_access_token) and is_binary(phi_data_token) and
             is_binary(resource_owner_private_key) and is_binary(client_private_key) do
    with {:ok, final_state} <- decode(phi_access_token),
         {:ok, base} <- BlsSignature.base(phi_data_token),
         {:ok, resource_owner_state} <- BlsSignature.scale(base, resource_owner_private_key),
         {:ok, reproduced_final_state} <-
           BlsSignature.scale(resource_owner_state, client_private_key) do
      reproduced_final_state == final_state
    else
      _ -> false
    end
  end

  def verify_with_private_keys(
        _phi_access_token,
        _phi_data_token,
        _resource_owner_private_key,
        _client_private_key
      ),
      do: false

  @doc """
  Uses one party's private key and the message to verify a supplied candidate
  public key as the remaining party in the final accumulator state.
  """
  @spec verify_remaining(String.t(), String.t(), binary(), binary()) :: boolean()
  def verify_remaining(phi_access_token, phi_data_token, party_private_key, candidate_public_key)
      when is_binary(phi_access_token) and is_binary(phi_data_token) and
             is_binary(party_private_key) and is_binary(candidate_public_key) do
    with {:ok, final_state} <- decode(phi_access_token),
         {:ok, base} <- BlsSignature.base(phi_data_token),
         {:ok, party_state} <- BlsSignature.scale(base, party_private_key) do
      BlsSignature.verify_transition(party_state, final_state, candidate_public_key)
    else
      _ -> false
    end
  end

  def verify_remaining(
        _phi_access_token,
        _phi_data_token,
        _party_private_key,
        _candidate_public_key
      ),
      do: false

  @doc """
  Creates a transferable proof of the remaining party using one participant's
  private key without including that private key in the proof.
  """
  @spec prove_remaining(String.t(), binary()) :: {:ok, String.t()} | {:error, String.t()}
  def prove_remaining(phi_access_token, party_private_key)
      when is_binary(phi_access_token) and is_binary(party_private_key) do
    with {:ok, final_state} <- decode(phi_access_token),
         {:ok, remaining_state} <- BlsSignature.unscale(final_state, party_private_key) do
      {:ok, encode_remaining_proof(remaining_state)}
    else
      :error -> {:error, "invalid phi access token"}
      error -> error
    end
  end

  def prove_remaining(_phi_access_token, _party_private_key),
    do: {:error, "invalid phi access token or private key"}

  @doc """
  Verifies a transferable remaining-party proof against the known participant
  and supplied candidate public keys.
  """
  @spec verify_remaining_proof(String.t(), String.t(), String.t(), binary(), binary()) ::
          boolean()
  def verify_remaining_proof(
        phi_access_token,
        phi_data_token,
        remaining_proof,
        known_party_public_key,
        candidate_public_key
      )
      when is_binary(phi_access_token) and is_binary(phi_data_token) and
             is_binary(remaining_proof) and is_binary(known_party_public_key) and
             is_binary(candidate_public_key) do
    with {:ok, final_state} <- decode(phi_access_token),
         {:ok, remaining_state} <- decode_remaining_proof(remaining_proof),
         {:ok, base} <- BlsSignature.base(phi_data_token) do
      BlsSignature.verify_transition(
        remaining_state,
        final_state,
        known_party_public_key
      ) and
        BlsSignature.verify_transition(base, remaining_state, candidate_public_key)
    else
      _ -> false
    end
  end

  def verify_remaining_proof(
        _phi_access_token,
        _phi_data_token,
        _remaining_proof,
        _known_party_public_key,
        _candidate_public_key
      ),
      do: false

  defp encode(<<final_state::binary-size(@signature_size)>>) do
    Base.url_encode64(<<@version, final_state::binary>>, padding: false)
  end

  defp decode(phi_access_token) do
    with {:ok, <<@version, final_state::binary-size(@signature_size)>>} <-
           Base.url_decode64(phi_access_token, padding: false) do
      {:ok, final_state}
    else
      _ -> :error
    end
  end

  defp encode_remaining_proof(<<remaining_state::binary-size(@signature_size)>>) do
    Base.url_encode64(<<@remaining_proof_version, remaining_state::binary>>, padding: false)
  end

  defp decode_remaining_proof(remaining_proof) do
    with {:ok, <<@remaining_proof_version, remaining_state::binary-size(@signature_size)>>} <-
           Base.url_decode64(remaining_proof, padding: false) do
      {:ok, remaining_state}
    else
      _ -> :error
    end
  end
end
