defmodule BorutaIdentity.RelyingParties do
  @moduledoc """
  The RelyingParties context.
  """

  import Ecto.Query, warn: false
  alias BorutaIdentity.Repo

  alias BorutaIdentity.RelyingParties.ClientRelyingParty
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
    relying_party
    |> RelyingParty.delete_changeset()
    |> Repo.delete()
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

  def upsert_client_relying_party(client_id, relying_party_id) do
    %ClientRelyingParty{}
    |> ClientRelyingParty.changeset(%{client_id: client_id, relying_party_id: relying_party_id})
    |> Repo.insert(
      on_conflict: [set: [relying_party_id: relying_party_id]],
      conflict_target: :client_id
    )
  end

  def remove_client_relying_party(client_id) do
    query = from(cr in ClientRelyingParty,
      where: cr.client_id == ^client_id,
      select: cr)
    case Repo.delete_all(query) do
      {1, [client_relying_party]} ->
        {:ok, client_relying_party}
      {0, []} ->
        {:ok, nil}
    end
  end

  def get_relying_party_by_client_id(client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, client_id} ->
        Repo.one(
          from(r in RelyingParty,
            join: crp in assoc(r, :client_relying_parties),
            where: crp.client_id == ^client_id
          )
        )

      :error ->
        nil
    end
  end

  alias BorutaIdentity.RelyingParties.Template

  @doc """
  Gets a relying_party template. Returns a default template if relying party template is not defined.

  Raises `Ecto.NoResultsError` if the Relying party does not exist.

  ## Examples

      iex> get_relying_party_template!(123, :new_registration)
      %Template{}

      iex> get_relying_party_template!(456, :new_registration)
      ** (Ecto.NoResultsError)

  """
  def get_relying_party_template!(relying_party_id, type) do
    case RelyingParty
    |> Repo.get!(relying_party_id)
    |> RelyingParty.template(type) do
      nil -> raise Ecto.NoResultsError, queryable: Template
      template -> template
    end
  end

  @doc """
  Upserts a template.

  ## Examples

      iex> upsert_template(template, %{field: new_value})
      {:ok, %Template{}}

      iex> upsert_template(template, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_template(%Template{id: template_id} = template, attrs) do
    changeset = Template.changeset(template, attrs)

    case template_id do
      nil -> Repo.insert(changeset)
      _ -> Repo.update(changeset)
    end
  end
end
