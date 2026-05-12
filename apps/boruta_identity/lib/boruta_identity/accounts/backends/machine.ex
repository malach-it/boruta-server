defmodule BorutaIdentity.Accounts.Machine do
  @moduledoc """
  Machine account implementation backed by a verifiable `id_token`.
  """

  import Ecto.Changeset
  import Ecto.Query

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

  @spec domain_user(ResourceOwner.t(), Backend.t()) ::
          {:ok, User.t()} | {:error, String.t()}
  def domain_user(%ResourceOwner{sub: id_token}, %Backend{} = backend) when is_binary(id_token) do
    with {:ok, _jwk, claims} <- VerifiablePresentations.validate_signature(id_token),
         {:ok, sub} <- fetch_sub(claims) do
      upsert_user(sub, id_token, claims, backend)
    end
  end

  def domain_user(_, _), do: {:error, "Machine id_token is missing."}

  def delete_user(_uid), do: :ok

  defp fetch_sub(%{"sub" => sub}) when is_binary(sub) and sub != "", do: {:ok, sub}
  defp fetch_sub(%{sub: sub}) when is_binary(sub) and sub != "", do: {:ok, sub}
  defp fetch_sub(_claims), do: {:error, "Machine id_token sub claim is missing."}

  defp upsert_user(sub, id_token, claims, %Backend{id: backend_id}) do
    attrs = %{
      uid: sub,
      username: sub,
      metadata:
        Map.put(claims, "id_token", id_token)
        |> Enum.map(fn {key, value} -> {key, %{"value" => value, "status" => "valid", "display" => []}} end)
        |> Enum.into(%{}),
      account_type: @account_type,
      backend_id: backend_id
    }

    changeset =
      %User{}
      |> cast(attrs, [:backend_id, :uid, :username, :metadata, :account_type])
      |> validate_required([:backend_id, :uid, :username, :account_type])
      |> validate_inclusion(:account_type, User.account_types())

    metadata = get_field(changeset, :metadata)

    changeset
    |> Repo.insert(
      on_conflict:
        from(u in User,
          update: [
            set: [
              username: ^sub,
              metadata: ^metadata
            ]
          ]
        ),
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> case do
      {:ok, user} ->
        {:ok, Repo.preload(user, [:authorized_scopes, :consents, :backend, :organizations])}

      {:error, changeset} ->
        {:error, inspect(changeset.errors)}
    end
  end
end
