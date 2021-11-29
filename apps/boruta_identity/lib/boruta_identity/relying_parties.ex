defmodule BorutaIdentity.RelyingParties do
  @moduledoc """
  The RelyingParties context.
  """

  import Ecto.Query, warn: false
  alias BorutaIdentity.Repo

  alias BorutaIdentity.RelyingParties.RelyingParty

  @doc """
  Returns the list of relying_parties.

  ## Examples

      iex> list_relying_parties()
      [%RelyingParty{}, ...]

  """
  def list_relying_parties do
    Repo.all(RelyingParty)
  end

  @doc """
  Gets a single relying_party.

  Raises `Ecto.NoResultsError` if the Relying party does not exist.

  ## Examples

      iex> get_relying_party!(123)
      %RelyingParty{}

      iex> get_relying_party!(456)
      ** (Ecto.NoResultsError)

  """
  def get_relying_party!(id), do: Repo.get!(RelyingParty, id)

  @doc """
  Creates a relying_party.

  ## Examples

      iex> create_relying_party(%{field: value})
      {:ok, %RelyingParty{}}

      iex> create_relying_party(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_relying_party(attrs \\ %{}) do
    %RelyingParty{}
    |> RelyingParty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a relying_party.

  ## Examples

      iex> update_relying_party(relying_party, %{field: new_value})
      {:ok, %RelyingParty{}}

      iex> update_relying_party(relying_party, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_relying_party(%RelyingParty{} = relying_party, attrs) do
    relying_party
    |> RelyingParty.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a relying_party.

  ## Examples

      iex> delete_relying_party(relying_party)
      {:ok, %RelyingParty{}}

      iex> delete_relying_party(relying_party)
      {:error, %Ecto.Changeset{}}

  """
  def delete_relying_party(%RelyingParty{} = relying_party) do
    Repo.delete(relying_party)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking relying_party changes.

  ## Examples

      iex> change_relying_party(relying_party)
      %Ecto.Changeset{data: %RelyingParty{}}

  """
  def change_relying_party(%RelyingParty{} = relying_party, attrs \\ %{}) do
    RelyingParty.changeset(relying_party, attrs)
  end
end
