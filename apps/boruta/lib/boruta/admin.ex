defmodule Boruta.Admin do
  @moduledoc """
  The Admin context.
  """

  import Ecto.Query, warn: false
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth.Client

  @doc """
  Returns the list of clients.

  ## Examples

      iex> list_clients()
      [%Client{}, ...]

  """
  def list_clients do
    repo().all(Client)
    |> repo().preload(:authorized_scopes)
  end

  @doc """
  Gets a single client.

  Raises `Ecto.NoResultsError` if the Client does not exist.

  ## Examples

      iex> get_client!(123)
      %Client{}

      iex> get_client!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client!(id) do
    repo().get!(Client, id)
    |> repo().preload(:authorized_scopes)
  end

  @doc """
  Creates a client.

  ## Examples

      iex> create_client(%{field: value})
      {:ok, %Client{}}

      iex> create_client(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_client(attrs \\ %{}) do
    %Client{}
    |> Client.create_changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates a client.

  ## Examples

      iex> update_client(client, %{field: new_value})
      {:ok, %Client{}}

      iex> update_client(client, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.update_changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a Client.

  ## Examples

      iex> delete_client(client)
      {:ok, %Client{}}

      iex> delete_client(client)
      {:error, %Ecto.Changeset{}}

  """
  def delete_client(%Client{} = client) do
    repo().delete(client)
  end

  alias Boruta.Oauth.Scope

  @doc """
  Returns the list of scopes.

  ## Examples

      iex> list_scopes()
      [%Scope{}, ...]

  """
  def list_scopes do
    repo().all(Scope)
  end

  @doc """
  Gets a single scope.

  Raises `Ecto.NoResultsError` if the Scope does not exist.

  ## Examples

      iex> get_scope!(123)
      %Scope{}

      iex> get_scope!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scope!(id), do: repo().get!(Scope, id)

  @doc """
  Creates a scope.

  ## Examples

      iex> create_scope(%{field: value})
      {:ok, %Scope{}}

      iex> create_scope(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scope(attrs \\ %{}) do
    %Scope{}
    |> Scope.changeset(attrs)
    |> repo().insert()
  end

  @doc """
  Updates a scope.

  ## Examples

      iex> update_scope(scope, %{field: new_value})
      {:ok, %Scope{}}

      iex> update_scope(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_scope(%Scope{} = scope, attrs) do
    scope
    |> Scope.changeset(attrs)
    |> repo().update()
  end

  @doc """
  Deletes a Scope.

  ## Examples

      iex> delete_scope(scope)
      {:ok, %Scope{}}

      iex> delete_scope(scope)
      {:error, %Ecto.Changeset{}}

  """
  def delete_scope(%Scope{} = scope) do
    repo().delete(scope)
  end
end
