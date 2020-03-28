defmodule BorutaGateway.Upstreams do
  @moduledoc """
  The Upstreams context.
  """

  import Ecto.Query, warn: false
  alias BorutaGateway.Repo

  alias BorutaGateway.Upstreams.Store
  alias BorutaGateway.Upstreams.Upstream

  def match(path) do
    Store.match(path)
  end

  @doc """
  Returns the list of upstreams.

  ## Examples

      iex> list_upstreams()
      [%Upstream{}, ...]

  """
  def list_upstreams do
    Repo.all(Upstream)
  end

  @doc """
  Gets a single upstream.

  Raises `Ecto.NoResultsError` if the Upstream does not exist.

  ## Examples

      iex> get_upstream!(123)
      %Upstream{}

      iex> get_upstream!(456)
      ** (Ecto.NoResultsError)

  """
  def get_upstream!(id), do: Repo.get!(Upstream, id)

  @doc """
  Creates a upstream.

  ## Examples

      iex> create_upstream(%{field: value})
      {:ok, %Upstream{}}

      iex> create_upstream(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_upstream(attrs \\ %{}) do
    %Upstream{}
    |> Upstream.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a upstream.

  ## Examples

      iex> update_upstream(upstream, %{field: new_value})
      {:ok, %Upstream{}}

      iex> update_upstream(upstream, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_upstream(%Upstream{} = upstream, attrs) do
    upstream
    |> Upstream.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a upstream.

  ## Examples

      iex> delete_upstream(upstream)
      {:ok, %Upstream{}}

      iex> delete_upstream(upstream)
      {:error, %Ecto.Changeset{}}

  """
  def delete_upstream(%Upstream{} = upstream) do
    Repo.delete(upstream)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking upstream changes.

  ## Examples

      iex> change_upstream(upstream)
      %Ecto.Changeset{source: %Upstream{}}

  """
  def change_upstream(%Upstream{} = upstream) do
    Upstream.changeset(upstream, %{})
  end
end
