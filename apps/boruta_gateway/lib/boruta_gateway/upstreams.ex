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
    changeset = Upstream.changeset(%Upstream{}, attrs)

    if Repo.backend() == "mnesia" do
      persist_mnesia(changeset, :insert)
    else
      Repo.insert(changeset)
    end
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
    changeset = Upstream.changeset(upstream, attrs)

    if Repo.backend() == "mnesia" do
      persist_mnesia(changeset, :update)
    else
      Repo.update(changeset)
    end
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

  defp persist_mnesia(changeset, action) do
    if changeset.valid? do
      {:ok, result} =
        Repo.transaction(fn ->
          :mnesia.write_lock_table(:upstreams)
          candidate = Ecto.Changeset.apply_changes(changeset)

          duplicate? =
            Repo.all(Upstream)
            |> Enum.any?(fn upstream ->
              upstream.id != candidate.id and
                {upstream.node_name, upstream.virtual_host, upstream.host, upstream.port,
                 upstream.uris} ==
                  {candidate.node_name, candidate.virtual_host, candidate.host, candidate.port,
                   candidate.uris}
            end)

          if duplicate? do
            {:error,
             Ecto.Changeset.add_error(changeset, :uris, "has already been taken",
               constraint: :unique,
               constraint_name: "upstreams_node_name_host_port_uris_index"
             )}
          else
            apply(Repo, action, [changeset])
          end
        end)

      result
    else
      {:error, changeset}
    end
  end
end
