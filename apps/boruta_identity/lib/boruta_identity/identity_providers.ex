defmodule BorutaIdentity.IdentityProviders do
  @moduledoc """
  The IdentityProviders context.
  """

  import Ecto.Query, warn: false
  alias BorutaIdentity.Repo

  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @doc """
  Returns the list of identity_providers.

  ## Examples

      iex> list_identity_providers()
      [%IdentityProvider{}, ...]

  """
  def list_identity_providers do
    Repo.all(IdentityProvider)
  end

  @doc """
  Gets a single identity_provider.

  Raises `Ecto.NoResultsError` if the identity provider does not exist.

  ## Examples

      iex> get_identity_provider!(123)
      %IdentityProvider{}

      iex> get_identity_provider!(456)
      ** (Ecto.NoResultsError)

  """
  def get_identity_provider!(id), do: Repo.get!(IdentityProvider, id)

  @doc """
  Creates a identity_provider.

  ## Examples

      iex> create_identity_provider(%{field: value})
      {:ok, %IdentityProvider{}}

      iex> create_identity_provider(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_identity_provider(attrs \\ %{}) do
    %IdentityProvider{}
    |> IdentityProvider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a identity_provider.

  ## Examples

      iex> update_identity_provider(identity_provider, %{field: new_value})
      {:ok, %IdentityProvider{}}

      iex> update_identity_provider(identity_provider, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_identity_provider(%IdentityProvider{} = identity_provider, attrs) do
    identity_provider
    |> IdentityProvider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a identity_provider.

  ## Examples

      iex> delete_identity_provider(identity_provider)
      {:ok, %IdentityProvider{}}

      iex> delete_identity_provider(identity_provider)
      {:error, %Ecto.Changeset{}}

  """
  def delete_identity_provider(%IdentityProvider{} = identity_provider) do
    identity_provider
    |> IdentityProvider.delete_changeset()
    |> Repo.delete()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking identity_provider changes.

  ## Examples

      iex> change_identity_provider(identity_provider)
      %Ecto.Changeset{data: %IdentityProvider{}}

  """
  def change_identity_provider(%IdentityProvider{} = identity_provider, attrs \\ %{}) do
    IdentityProvider.changeset(identity_provider, attrs)
  end

  def upsert_client_identity_provider(client_id, identity_provider_id) do
    %ClientIdentityProvider{}
    |> ClientIdentityProvider.changeset(%{client_id: client_id, identity_provider_id: identity_provider_id})
    |> Repo.insert(
      on_conflict: [set: [identity_provider_id: identity_provider_id]],
      conflict_target: :client_id
    )
  end

  def remove_client_identity_provider(client_id) do
    query =
      from(cr in ClientIdentityProvider,
        where: cr.client_id == ^client_id,
        select: cr
      )

    case Repo.delete_all(query) do
      {1, [client_identity_provider]} ->
        {:ok, client_identity_provider}

      {0, []} ->
        {:ok, nil}
    end
  end

  def get_identity_provider_by_client_id(client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, client_id} ->
        Repo.one(
          from(r in IdentityProvider,
            join: crp in assoc(r, :client_identity_providers),
            where: crp.client_id == ^client_id
          )
        )

      :error ->
        nil
    end
  end

  alias BorutaIdentity.IdentityProviders.Template

  @doc """
  Gets a identity_provider template. Returns a default template if identity provider template is not defined.

  Raises `Ecto.NoResultsError` if the identity provider does not exist.

  ## Examples

      iex> get_identity_provider_template!(123, :new_registration)
      %Template{}

      iex> get_identity_provider_template!(456, :new_registration)
      ** (Ecto.NoResultsError)

  """
  def get_identity_provider_template!(identity_provider_id, type) do
    with %IdentityProvider{} = identity_provider <-
           Repo.one(
             from(rp in IdentityProvider,
               left_join: t in assoc(rp, :templates),
               where: rp.id == ^identity_provider_id,
               preload: [templates: t]
             )
           ),
         %Template{} = template <- IdentityProvider.template(identity_provider, type) do
      %{template | layout: IdentityProvider.template(identity_provider, :layout)}
    else
      nil -> raise Ecto.NoResultsError, queryable: Template
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

  @doc """
  Deletes a identity provider template.

  ## Examples

      iex> delete_identity_provider_template!(template, :new_session)
      {:ok, %Template{}}

      iex> delete_identity_provider_template!(template, :unknown)
      ** (Ecto.NoResultsError)

  """
  def delete_identity_provider_template!(identity_provider_id, type) do
    template_type = Atom.to_string(type)

    with {1, _results} <-
           Repo.delete_all(
             from(t in Template,
               join: rp in assoc(t, :identity_provider),
               where:
                 rp.id == ^identity_provider_id and
                   t.type == ^template_type
             )
           ),
         %Template{} = template <- get_identity_provider_template!(identity_provider_id, type) do
      template
    else
      {0, nil} -> raise Ecto.NoResultsError, queryable: Template
    end
  end
end
