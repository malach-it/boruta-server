defmodule BorutaIdentity.Clients do
  @moduledoc false

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias BorutaAuth.KeyPairs
  alias BorutaAuth.KeyPairs.KeyPair
  alias BorutaIdentity.IdentityProviders

  def create_client(client_params) do
    identity_provider_id = get_in(client_params, ["identity_provider", "id"])

    BorutaAuth.Repo.transaction(fn ->
      with {:ok, client} <- Admin.create_client(client_params),
           {:ok, client} <- insert_global_key_pair(client, client_params["key_pair_id"]),
           {:ok, _client_identity_provider} <-
             IdentityProviders.upsert_client_identity_provider(
               client.id,
               identity_provider_id
             ) do
        client
      else
        {:error, error} ->
          BorutaAuth.Repo.rollback(error)
      end
    end)
  end

  def insert_global_key_pair(%Client{} = client, nil), do: {:ok, client}
  def insert_global_key_pair(%Client{} = client, key_pair_id) do
    %KeyPair{public_key: public_key, private_key: private_key} =
      KeyPairs.get_key_pair!(key_pair_id)

    Admin.regenerate_client_key_pair(client, public_key, private_key)
  end
end
