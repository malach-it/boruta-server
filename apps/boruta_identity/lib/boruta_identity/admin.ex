defmodule BorutaIdentity.Admin do
  @moduledoc """
  TODO Admin documentation
  """

  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.{UserAuthorizedScope}
  alias BorutaIdentity.Repo

  @doc """
  List all users

  ## Examples

      iex> list_users()
      [...]
  """
  @spec list_users() :: list(User.t())
  def list_users do
    Repo.all(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        preload: [authorized_scopes: as]
      )
    )
  end

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  @spec get_user(id :: Ecto.UUID.t()) :: user :: User.t() | nil
  def get_user(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        preload: [authorized_scopes: as],
        where: u.id == ^id
      )
    )
  end

  @spec update_user_authorized_scopes(user :: %User{}, scopes :: list(map())) ::
          {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def update_user_authorized_scopes(%User{id: user_id} = user, scopes) do
    Repo.delete_all(from(s in UserAuthorizedScope, where: s.user_id == ^user_id))

    case Enum.reduce(scopes, Ecto.Multi.new(), fn attrs, multi ->
           changeset =
             UserAuthorizedScope.changeset(
               %UserAuthorizedScope{},
               Map.put(attrs, "user_id", user_id)
             )

           Ecto.Multi.insert(multi, "scope_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> Repo.preload(:authorized_scopes)}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec delete_user(user_id :: Ecto.UUID.t()) ::
          {:ok, user :: User.t()} | {:error, atom()} | {:error, Ecto.Changeset.t()}
  def delete_user(user_id) when is_binary(user_id) do
    case get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        Repo.delete(user)
    end
  end
end
