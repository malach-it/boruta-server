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
    Repo.all(
      from idp in IdentityProvider,
        join: b in assoc(idp, :backend),
        preload: [backend: b]
    )
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
  def get_identity_provider!(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Repo.one!(
          from idp in IdentityProvider,
            join: b in assoc(idp, :backend),
            where: idp.id == ^id,
            preload: [backend: b]
        )

      _ ->
        raise Ecto.NoResultsError, queryable: IdentityProvider
    end
  end

  @doc """
  Creates a identity_provider.

  ## Examples

      iex> create_identity_provider(%{field: value})
      {:ok, %IdentityProvider{}}

      iex> create_identity_provider(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_identity_provider(attrs \\ %{}) do
    with {:ok, identity_provider} <-
           %IdentityProvider{}
           |> IdentityProvider.changeset(attrs)
           |> Repo.insert() do
      {:ok, Repo.preload(identity_provider, :backend)}
    end
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
    |> ClientIdentityProvider.changeset(%{
      client_id: client_id,
      identity_provider_id: identity_provider_id
    })
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
          from(idp in IdentityProvider,
            join: b in assoc(idp, :backend),
            join: cidp in assoc(idp, :client_identity_providers),
            where: cidp.client_id == ^client_id,
            preload: [backend: b]
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
             from(idp in IdentityProvider,
               left_join: t in assoc(idp, :templates),
               join: b in assoc(idp, :backend),
               where: idp.id == ^identity_provider_id,
               preload: [backend: b, templates: t]
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

  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders.Backend

  @doc """
  Returns the list of backends.

  ## Examples

      iex> list_backends()
      [%Backend{}, ...]

  """
  def list_backends do
    Repo.all(Backend)
  end

  @doc """
  Gets a single backend.

  Raises `Ecto.NoResultsError` if the Backend does not exist.

  ## Examples

      iex> get_backend!(123)
      %Backend{}

      iex> get_backend!(456)
      ** (Ecto.NoResultsError)

  """
  def get_backend!(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get!(Backend, id)
      _ -> raise Ecto.NoResultsError, queryable: Backend
    end
  end

  # TODO client backend association
  # def get_backend_by_client_id(client_id) do
  #   case Ecto.UUID.cast(client_id) do
  #     {:ok, client_id} ->
  #       Repo.one(
  #         from(b in Backend,
  #           join: idp in assoc(b, :identity_providers),
  #           join: cidp in assoc(idp, :client_identity_providers),
  #           where: cidp.client_id == ^client_id
  #         )
  #       )

  #     :error ->
  #       nil
  #   end
  # end

  @doc """
  Creates a backend.

  ## Examples

      iex> create_backend(%{field: value})
      {:ok, %Backend{}}

      iex> create_backend(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_backend(attrs \\ %{}) do
    %Backend{type: "Elixir.BorutaIdentity.Accounts.Internal"}
    |> Backend.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a backend.

  ## Examples

      iex> update_backend(backend, %{field: new_value})
      {:ok, %Backend{}}

      iex> update_backend(backend, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_backend(%Backend{} = backend, attrs) do
    ldap_pool_name = Ldap.pool_name(backend)

    with {:ok, backend} <-
           backend
           |> Backend.changeset(attrs)
           |> Repo.update() do
      Process.whereis(ldap_pool_name) &&
        NimblePool.stop(ldap_pool_name)

      {:ok, backend}
    end
  end

  @doc """
  Deletes a backend.

  ## Examples

      iex> delete_backend(backend)
      {:ok, %Backend{}}

      iex> delete_backend(backend)
      {:error, %Ecto.Changeset{}}

  """
  def delete_backend(%Backend{} = backend) do
    ldap_pool_name = Ldap.pool_name(backend)

    with {:ok, backend} <-
           backend
           |> Backend.delete_changeset()
           |> Repo.delete() do
      Process.whereis(ldap_pool_name) &&
        NimblePool.stop(ldap_pool_name)

      {:ok, backend}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking backend changes.

  ## Examples

      iex> change_backend(backend)
      %Ecto.Changeset{data: %Backend{}}

  """
  def change_backend(%Backend{} = backend, attrs \\ %{}) do
    Backend.changeset(backend, attrs)
  end
end
