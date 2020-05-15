defmodule BorutaIdentityProvider.Accounts do
  @moduledoc """
  TODO Admin Users documentation
  """

  import Ecto.Query, warn: false
  import BorutaIdentityProvider.Config, only: [repo: 0]

  alias BorutaIdentityProvider.Accounts.User
  alias BorutaIdentityProvider.Accounts.UserAuthorizedScope

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    repo().all(User)
    |> Enum.map(&format_user(&1))
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
    |> format_user()
  end

  @doc """
  Gets a user given params.

  ## Examples

      iex> get_user_by(id: 123)
      %User{}

  """
  def get_user_by(params) do
    repo().get_by(User, params)
    |> format_user()
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
      {:ok, format_user(user)}
    end
  end

  defp format_user(nil), do: nil
  defp format_user(user) do
    %User{authorized_scopes: authorized_scopes} = repo().preload(user, :authorized_scopes)
    authorized_scope_ids = Enum.map(authorized_scopes, fn (%UserAuthorizedScope{scope_id: id}) -> id end)
    authorized_scopes = Boruta.Ecto.Admin.get_scopes_by_ids(authorized_scope_ids)
    |> Enum.map(fn (scope) ->
      struct(Boruta.Oauth.Scope, Map.from_struct(scope))
    end)

    %{user|authorized_scopes: authorized_scopes}
  end
end
