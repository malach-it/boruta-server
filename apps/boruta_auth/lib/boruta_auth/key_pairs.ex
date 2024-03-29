defmodule BorutaAuth.KeyPairs do
  @moduledoc false

  import Ecto.Query

  alias Boruta.Ecto.Client
  alias Boruta.Oauth.Client.Crypto
  alias BorutaAuth.KeyPairs.KeyPair
  alias BorutaAuth.Repo

  def list_key_pairs do
    Repo.all(KeyPair)
  end

  def get_key_pair!(id) do
    Repo.get!(KeyPair, id)
  end

  def list_jwks do
    Repo.all(KeyPair)
    |> Enum.map(&rsa_key/1)
  end

  def create_key_pair(attrs \\ %{}) do
    KeyPair.changeset(%KeyPair{}, attrs)
    |> Repo.insert()
  end

  def update_key_pair(key_pair, attrs \\ %{}) do
    KeyPair.changeset(key_pair, attrs)
    |> Repo.update()
  end

  def delete_key_pair(%KeyPair{} = key_pair) do
    key_pair
    |> KeyPair.delete_changeset()
    |> Repo.delete()
  end

  def rotate(%KeyPair{private_key: private_key} = key_pair) do
    with {:ok, key_pair} <- KeyPair.rotate_changeset(key_pair) |> Repo.update() do
      Repo.update_all(
        from(c in Client, where: c.private_key == ^private_key, select: c.id),
        set: [
          public_key: key_pair.public_key,
          private_key: key_pair.private_key
        ]
      )
      {:ok, key_pair}
    end
  end

  defp rsa_key(%KeyPair{} = key_pair) do
    {_type, jwk} = key_pair.public_key |> :jose_jwk.from_pem() |> :jose_jwk.to_map()

    Map.put(jwk, "kid", Crypto.kid_from_private_key(key_pair.private_key))
  end
end
