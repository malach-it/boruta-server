defmodule BorutaIdentity.IdentityProviders do
  @moduledoc """
  The IdentityProviders context.
  """

  import Ecto.Query, warn: false
  alias BorutaIdentity.Repo

  alias Boruta.Ecto.Scopes
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.IdentityProviders.BackendRole
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider

  def list_identity_providers do
    Repo.all(
      from idp in IdentityProvider,
        join: b in assoc(idp, :backend),
        left_join: et in assoc(b, :email_templates),
        preload: [backend: {b, email_templates: et}]
    )
  end

  def get_identity_provider!(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Repo.one!(
          from idp in IdentityProvider,
            join: b in assoc(idp, :backend),
            left_join: et in assoc(b, :email_templates),
            where: idp.id == ^id,
            preload: [backend: {b, email_templates: et}]
        )

      _ ->
        raise Ecto.NoResultsError, queryable: IdentityProvider
    end
  end

  def create_identity_provider(attrs \\ %{}) do
    with {:ok, identity_provider} <-
           %IdentityProvider{}
           |> IdentityProvider.changeset(attrs)
           |> Repo.insert() do
      {:ok, Repo.preload(identity_provider, :backend)}
    end
  end

  def update_identity_provider(%IdentityProvider{} = identity_provider, attrs) do
    identity_provider
    |> IdentityProvider.changeset(attrs)
    |> Repo.update()
  end

  def delete_identity_provider(%IdentityProvider{} = identity_provider) do
    identity_provider
    |> IdentityProvider.delete_changeset()
    |> Repo.delete()
  end

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
            left_join: et in assoc(b, :email_templates),
            join: cidp in assoc(idp, :client_identity_providers),
            where: cidp.client_id == ^client_id,
            preload: [backend: {b, email_templates: et}]
          )
        )

      :error ->
        nil
    end
  end

  alias BorutaIdentity.IdentityProviders.Template

  def get_identity_provider_template!(identity_provider_id, type) do
    with %IdentityProvider{} = identity_provider_with_templates <-
           Repo.one(
             from(idp in IdentityProvider,
               left_join: t in assoc(idp, :templates),
               join: b in assoc(idp, :backend),
               where: idp.id == ^identity_provider_id,
               preload: [backend: b, templates: t]
             )
           ),
         %Template{} = template <- IdentityProvider.template(identity_provider_with_templates, type) do
      %{template | layout: IdentityProvider.template(identity_provider_with_templates, :layout)}
    else
      nil -> raise Ecto.NoResultsError, queryable: Template
    end
  end

  def upsert_template(%Template{id: template_id} = template, attrs) do
    changeset = Template.changeset(template, attrs)

    case template_id do
      nil -> Repo.insert(changeset)
      _ -> Repo.update(changeset)
    end
  end

  def delete_identity_provider_template!(identity_provider_id, type) do
    template_type = Atom.to_string(type)

    with {1, _results} <-
           Repo.delete_all(
             from(t in Template,
               join: idp in assoc(t, :identity_provider),
               where:
                 idp.id == ^identity_provider_id and
                   t.type == ^template_type
             )
           ),
         %Template{} = template <- get_identity_provider_template!(identity_provider_id, type) do
      template
    else
      {0, nil} -> raise Ecto.NoResultsError, queryable: Template
      nil -> raise Ecto.NoResultsError, queryable: Template
    end
  end

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders.Backend

  def list_backends do
    Repo.all(Backend)
  end

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

  def create_backend(attrs \\ %{}) do
    with {:ok, backend} <-
           %Backend{type: "Elixir.BorutaIdentity.Accounts.Internal"}
           |> Backend.changeset(attrs)
           |> Repo.insert() do
      update_backend_roles(backend, attrs["roles"] || [])
    end
  end

  def update_backend(%Backend{} = backend, attrs) do
    ldap_pool_name = Ldap.pool_name(backend)

    with {:ok, backend} <-
           backend
           |> Backend.changeset(attrs)
           |> Repo.update(),
         {:ok, backend} <- update_backend_roles(backend, attrs["roles"] || []) do
      Process.whereis(ldap_pool_name) &&
        NimblePool.stop(ldap_pool_name)

      {:ok, backend}
    end
  end

  @spec update_backend_roles(backend :: %Backend{}, roles :: list(map())) ::
          {:ok, %Backend{}} | {:error, Ecto.Changeset.t()}
  def update_backend_roles(%Backend{id: backend_id} = backend, roles) do
    Repo.delete_all(from(s in BackendRole, where: s.backend_id == ^backend_id))

    case Enum.reduce(roles, Ecto.Multi.new(), fn attrs, multi ->
           changeset =
             BackendRole.changeset(
               %BackendRole{},
               %{
                 "role_id" => attrs["id"] || attrs[:role_id],
                 "backend_id" => backend.id
               }
             )

           Ecto.Multi.insert(multi, "role_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, backend |> Repo.reload()}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec get_backend_roles(backend_id :: String.t()) :: backend :: list(BackendRole.t()) | nil
  def get_backend_roles(backend_id) do
    scopes = Scopes.all()

    Repo.all(
      from(br in BackendRole,
        left_join: r in assoc(br, :role),
        left_join: rs in assoc(r, :role_scopes),
        where: br.backend_id == ^backend_id,
        preload: [role: {r, [role_scopes: rs]}]
      )
    )
    |> Enum.map(fn %{role: role} ->
      %{
        role
        | scopes:
            role.role_scopes
            |> Enum.map(fn role_scope ->
              Enum.find(scopes, fn %{id: id} -> id == role_scope.scope_id end)
            end)
            |> Enum.flat_map(fn
              %{id: id, name: name} -> [%Scope{id: id, name: name}]
              _ -> []
            end)
      }
    end)
  end

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

  def get_backend_email_template!(backend_id, type) do
    with %Backend{} = backend <-
           Repo.one(
             from(b in Backend,
               left_join: t in assoc(b, :email_templates),
               where: b.id == ^backend_id,
               preload: [email_templates: t]
             )
           ),
         %EmailTemplate{} = template <- Backend.email_template(backend, type) do
      template
    else
      nil -> raise Ecto.NoResultsError, queryable: Template
    end
  end

  def upsert_email_template(%EmailTemplate{id: template_id} = template, attrs) do
    changeset = EmailTemplate.changeset(template, attrs)

    case template_id do
      nil -> Repo.insert(changeset)
      _ -> Repo.update(changeset)
    end
  end

  @doc """
  Deletes an email template.

  ## Examples

      iex> delete_email_template!(template, :reset_password)
      {:ok, %EmailTemplate{}}

      iex> delete_email_template!(template, :unknown)
      ** (Ecto.NoResultsError)

  """

  def delete_email_template!(backend_id, type) do
    template_type = Atom.to_string(type)

    with {1, _results} <-
           Repo.delete_all(
             from(t in EmailTemplate,
               join: b in assoc(t, :backend),
               where:
                 b.id == ^backend_id and
                   t.type == ^template_type
             )
           ),
         %EmailTemplate{} = template <- get_backend_email_template!(backend_id, type) do
      template
    else
      {0, nil} -> raise Ecto.NoResultsError, queryable: Template
      nil -> raise Ecto.NoResultsError, queryable: Template
    end
  end
end
