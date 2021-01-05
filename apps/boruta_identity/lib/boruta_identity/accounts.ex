defmodule BorutaIdentity.Accounts do
  @moduledoc """
  TODO Admin Users documentation
  """

  import Ecto.Query, warn: false
  import BorutaIdentity.Config, only: [repo: 0]

  alias BorutaIdentity.Accounts.HashSalt
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    repo().all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    repo().get!(User, id)
  end

  @doc """
  Checks user password

  ## Examples

      iex> check_password(%User{}, password)
      :ok

  """
  def check_password(%User{password_hash: password_hash}, password) do
    case HashSalt.checkpw(password, password_hash) do
      true -> :ok
      false -> {:error, "Invalid password."}
    end
  end

  @doc """
  Gets a user given params.

  ## Examples

      iex> get_user_by(id: 123)
      %User{}

  """
  def get_user_by(params) do
    repo().get_by(User, params)
  end

  @doc """
  Updates an user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
  with %User{} = user <- repo().get!(User, user.id),
       {:ok, user} <- user
       |> User.update_changeset!(attrs)
       |> repo().update() do
      {:ok, user}
    end
  end

  @doc """
  Get user scopes.

  ## Examples

      iex> get_user_scopes("f8eadd9e-7680-493e-800b-3f3604d7c5a0")
      []

  """
  def get_user_scopes(id) do
    repo().all(UserAuthorizedScope, user_id: id)
  end
end
