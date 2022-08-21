defmodule BorutaIdentity.Admin do
  @moduledoc """
  TODO Admin documentation
  """

  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @type user_params :: %{
          username: String.t(),
          password: String.t()
        }

  @callback delete_user(id :: String.t()) :: :ok | {:error, reason :: any()}
  @callback create_user(
              backend :: Backend.t(),
              params :: user_params()
            ) ::
              {:ok, User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  @doc """
  List all users

  ## Examples

      iex> list_users()
      [...]
  """
  @spec list_users() :: Scrivener.Page.t()
  def list_users(params \\ %{}) do
    from(u in User)
    |> preload([:authorized_scopes, :backend])
    |> Repo.paginate(params)
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
        join: b in assoc(u, :backend),
        preload: [authorized_scopes: as, backend: b],
        where: u.id == ^id
      )
    )
  end

  @spec create_user(backend :: Backend.t(), params :: user_params()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(backend, params) do
    # TODO give the ability to provide authorized scopes at user creation
    apply(
      Backend.implementation(backend),
      :create_user,
      [backend, params]
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
               %{
                 "scope_id" => attrs["id"],
                 "user_id" => user.id
               }
             )

           Ecto.Multi.insert(multi, "scope_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> Repo.preload([:backend, :authorized_scopes])}

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
        # TODO delete both provider and domain users in a transaction
        apply(Backend.implementation(user.backend), :delete_user, [user.uid])
        Repo.delete(user)
    end
  end

  @spec delete_user_authorized_scopes_by_id(scope_id :: String.t()) :: {deleted :: integer(), nil}
  def delete_user_authorized_scopes_by_id(scope_id) do
    Repo.delete_all(from(s in UserAuthorizedScope, where: s.scope_id == ^scope_id))
  end
end
