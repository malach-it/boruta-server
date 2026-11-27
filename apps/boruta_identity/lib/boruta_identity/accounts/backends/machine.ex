defmodule BorutaIdentity.Accounts.Machine do
  @moduledoc """
  Machine account implementation backed by a verifiable `id_token`.
  """

  import Ecto.Changeset

  alias Boruta.Did
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid.VerifiablePresentations
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @features [
    :destroyable
  ]

  def features, do: @features

  @account_type "machine"

  def account_type, do: @account_type

  @spec domain_user!(ResourceOwner.t(), Backend.t()) ::
          {:ok, User.t()} | {:error, String.t()}
  def domain_user!(%ResourceOwner{sub: id_token}, %Backend{} = backend)
      when is_binary(id_token) do
    with {:ok, jwk, claims} <- VerifiablePresentations.validate_signature(id_token),
         {:ok, sub} <- did_from_jwk(jwk) do
      metadata = user_metadata(claims["metadata_policy"] || %{})

      case Repo.get_by(User, backend_id: backend.id, did: sub) do
        nil ->
          insert_user(sub, metadata, backend)

        %User{metadata: ^metadata} = user ->
          {:ok, Repo.preload(user, [:authorized_scopes, :consents, :backend, :organizations])}

        _ ->
          {:error, "Machine metadata policy changed."}
      end
    end
  end

  def domain_user!(_, _), do: {:error, "Machine id_token is missing."}

  def delete_user(_did), do: :ok

  defp did_from_jwk(jwk) do
    case Did.create("key", jwk) do
      {:ok, did, _jwk} -> {:ok, did}
      {:error, error} -> {:error, error}
    end
  end

  defp insert_user(sub, metadata, %Backend{id: backend_id}) do
    attrs = %{
      uid: sub,
      did: sub,
      username: sub,
      account_type: @account_type,
      backend_id: backend_id,
      metadata: metadata
    }

    changeset =
      %User{}
      |> cast(attrs, [:backend_id, :username, :uid, :did, :account_type, :metadata])
      |> validate_required([:backend_id, :did, :account_type, :metadata])
      |> validate_inclusion(:account_type, User.account_types())

    changeset
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, Repo.preload(user, [:authorized_scopes, :consents, :backend, :organizations])}

      {:error, changeset} ->
        {:error, inspect(changeset.errors)}
    end
  end

  defp user_metadata(metadata_policy) do
    Map.new(metadata_policy, fn {key, value} ->
      {key, %{"value" => value, "status" => "stale", "display" => []}}
    end)
  end
end
