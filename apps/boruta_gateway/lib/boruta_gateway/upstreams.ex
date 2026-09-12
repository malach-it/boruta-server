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

  def match(host, path) do
    Store.match(host, path)
  end

  def sidecar_match(path) do
    Store.sidecar_match(path)
  end

  def sidecar_match(host, path) do
    Store.sidecar_match(host, path)
  end

  @doc """
  Returns the list of upstreams.

  ## Examples

      iex> list_upstreams()
      [%Upstream{}, ...]

  """
  def list_upstreams do
    Upstream
    |> Repo.all()
    |> Enum.group_by(fn %Upstream{node_name: node_name} -> node_name end)
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

  def sync_managed_upstreams(managed_by, upstream_attrs) do
    managed_ids = Enum.map(upstream_attrs, &Map.fetch!(&1, :managed_id))

    Repo.transaction(fn ->
      delete_stale_managed_upstreams(managed_by, managed_ids)

      Enum.map(upstream_attrs, fn attrs ->
        attrs = Map.put(attrs, :managed_by, managed_by)

        case Repo.get_by(Upstream, managed_by: managed_by, managed_id: attrs.managed_id) do
          nil ->
            {:ok, upstream} = create_upstream(attrs)
            upstream

          %Upstream{} = upstream ->
            {:ok, upstream} = update_upstream(upstream, attrs)
            upstream
        end
      end)
    end)
  end

  defp delete_stale_managed_upstreams(managed_by, []) do
    Upstream
    |> where([upstream], upstream.managed_by == ^managed_by)
    |> Repo.delete_all()
  end

  defp delete_stale_managed_upstreams(managed_by, managed_ids) do
    Upstream
    |> where([upstream], upstream.managed_by == ^managed_by)
    |> where([upstream], upstream.managed_id not in ^managed_ids)
    |> Repo.delete_all()
  end
end
