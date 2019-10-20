defmodule Boruta.Admin.Users do
  @moduledoc """
  TODO Admin Users documentation
  """

  import Ecto.Query, warn: false
  import Boruta.Config, only: [repo: 0, resource_owner_schema: 0]

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    users = repo().all(resource_owner_schema())

    repo().preload(users, :authorized_scopes)
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
    user = repo().get!(resource_owner_schema(), id)

    repo().preload(user, :authorized_scopes)
  end

  @doc """
  Updates an user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%_{} = user, attrs) do
    user
    |> resource_owner_schema().update_changeset!(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%_{} = user) do
    repo().delete(user)
  end
end
