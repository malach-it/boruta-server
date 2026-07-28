defmodule BorutaIdentity.PhiAccessProof do
  @moduledoc """
  Adds one consent-bound user/client aggregate BLS proof per disclosed metadata
  attribute in UserInfo and ID-token claims.
  """

  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token
  alias BorutaAuth.BlsKeyPair
  alias BorutaAuth.ClientBlsKeyPair
  alias BorutaAuth.PhiAccessToken
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  @spec add(map(), Token.t()) :: {:ok, map()} | {:error, String.t()}
  def add(userinfo, %Token{client: %{id: client_id}, scope: scope} = token)
      when is_map(userinfo) do
    with %User{} = user <- Accounts.get_user(resource_owner_id(token)) do
      add_for_client(userinfo, user, client_id, scope)
    else
      _ -> {:ok, userinfo}
    end
  end

  def add(userinfo, _token), do: {:ok, userinfo}

  @doc """
  Adds proofs for metadata disclosed within the consented scope supplied to
  `ResourceOwners.claims/2`.
  """
  @spec add_for_client(map(), User.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def add_for_client(claims, %User{} = user, client_id, scope) when is_map(claims) do
    with %ClientBlsKeyPair{} = client_key_pair <- ClientBlsKeyPair.get(client_id) do
      add_metadata_proofs(claims, user, client_key_pair, Scope.split(scope))
    else
      _ -> {:ok, claims}
    end
  end

  def add_for_client(claims, _user, _client_id, _scope), do: {:ok, claims}

  defp resource_owner_id(%Token{resource_owner: %{sub: sub}}) when is_binary(sub), do: sub
  defp resource_owner_id(%Token{sub: sub}), do: sub

  defp add_metadata_proofs(userinfo, user, client_key_pair, consented_scopes) do
    user.metadata
    |> Enum.filter(fn
      {attribute_name, %{"phi_data_token" => phi_data_token, "value" => value}}
      when is_binary(phi_data_token) ->
        Map.has_key?(userinfo, attribute_name) and
          metadata_consented?(user, attribute_name, consented_scopes) and
          BlsKeyPair.verify_phi_data_token(
            user.bls_public_key,
            attribute_name,
            value,
            phi_data_token
          )

      _ ->
        false
    end)
    |> Enum.reduce_while({:ok, %{}}, fn
      {attribute_name, %{"phi_data_token" => phi_data_token}}, {:ok, proofs} ->
        with {:ok, phi_access_token} <-
               PhiAccessToken.issue(
                 phi_data_token,
                 user.bls_private_key,
                 client_key_pair.private_key
               ),
             {:ok, resource_owner_key_proof} <-
               PhiAccessToken.prove_remaining(
                 phi_access_token,
                 client_key_pair.private_key
               ) do
          proof = %{
            "type" => "Bls12381G2SequentialAccumulator",
            "phi_data_token" => phi_data_token,
            "phi_access_token" => phi_access_token,
            "resource_owner_bls_did_key" => user.bls_did_key,
            "resource_owner_key_proof" => %{
              "type" => "Bls12381G2RemainingPartyProof",
              "value" => resource_owner_key_proof
            }
          }

          {:cont, {:ok, Map.put(proofs, attribute_name, proof)}}
        else
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
    |> case do
      {:ok, proofs} when map_size(proofs) == 0 -> {:ok, userinfo}
      {:ok, proofs} -> {:ok, Map.put(userinfo, "_proof", proofs)}
      error -> error
    end
  end

  defp metadata_consented?(user, attribute_name, consented_scopes) do
    required_scopes =
      user.backend.metadata_fields
      |> Enum.find_value([], fn
        %{"attribute_name" => ^attribute_name} = field -> field["scopes"] || []
        _field -> nil
      end)

    Enum.empty?(required_scopes -- consented_scopes)
  end
end
