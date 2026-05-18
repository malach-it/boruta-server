defmodule BorutaIdentity.IdentityProviders do
  @moduledoc """
  The IdentityProviders context.
  """

  use Nebulex.Caching, cache: BorutaIdenity.Cache
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
    clear_identity_provider_by_client_id_cache()
    clear_identity_provider_templates_cache(identity_provider, attrs)

    identity_provider
    |> IdentityProvider.changeset(attrs)
    |> Repo.update()
  end

  def delete_identity_provider(%IdentityProvider{} = identity_provider) do
    clear_identity_provider_by_client_id_cache()

    identity_provider
    |> IdentityProvider.delete_changeset()
    |> Repo.delete()
  end

  def change_identity_provider(%IdentityProvider{} = identity_provider, attrs \\ %{}) do
    IdentityProvider.changeset(identity_provider, attrs)
  end

  def upsert_client_identity_provider(client_id, identity_provider_id) do
    clear_identity_provider_by_client_id_cache()

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

  defp clear_identity_provider_by_client_id_cache do
    {:ok, _count} =
      Boruta.Cache.delete_all(
        query: [
          {
            {:entry, {BorutaIdentity.IdentityProviders, :identity_provider_by_client_id, :"$1"},
             :"$2", :"$3", :"$4"},
            [],
            [true]
          }
        ]
      )

    :ok
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

  @decorate cacheable(
              key: {__MODULE__, :identity_provider_by_client_id, client_id},
              cache: Boruta.Cache
            )
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

  @decorate cacheable(
              key: {__MODULE__, :identity_provider_template, identity_provider_id, type},
              cache: Boruta.Cache
            )
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
         %Template{} = template <-
           IdentityProvider.template(identity_provider_with_templates, type) do
      %{template | layout: IdentityProvider.template(identity_provider_with_templates, :layout)}
    else
      nil -> raise Ecto.NoResultsError, queryable: Template
    end
  end

  def upsert_template(%Template{id: template_id} = template, attrs) do
    :ok = clear_identity_provider_templates_cache(template.identity_provider_id, [template.type])

    changeset = Template.changeset(template, attrs)

    case template_id do
      nil -> Repo.insert(changeset)
      _ -> Repo.update(changeset)
    end
  end

  def delete_identity_provider_template!(identity_provider_id, type) do
    template_type = Atom.to_string(type)

    with :ok <-
           clear_identity_provider_templates_cache(identity_provider_id, [type]),
         {1, _results} <-
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

  defp clear_identity_provider_templates_cache(%IdentityProvider{id: identity_provider_id}, attrs) do
    types =
      attrs
      |> Map.get(:templates, Map.get(attrs, "templates", []))
      |> Enum.map(&Map.get(&1, :type, Map.get(&1, "type")))
      |> Enum.reject(&is_nil/1)

    clear_identity_provider_templates_cache(identity_provider_id, types)
  end

  defp clear_identity_provider_templates_cache(_identity_provider_id, []), do: :ok

  defp clear_identity_provider_templates_cache(identity_provider_id, types) when is_list(types) do
    normalized_types = Enum.map(types, &normalize_template_type/1)

    clear_identity_provider_templates_cache(identity_provider_id, normalized_types, [])
  end

  defp clear_identity_provider_templates_cache(_identity_provider_id, [], _cleared_types), do: :ok

  defp clear_identity_provider_templates_cache(
         identity_provider_id,
         [type | types],
         cleared_types
       ) do
    :ok = clear_identity_provider_templates_cache_key(identity_provider_id, type, cleared_types)

    types =
      if type == :layout and type not in cleared_types do
        Enum.reject(Template.template_types(), &(&1 == :layout)) ++ types
      else
        types
      end

    clear_identity_provider_templates_cache(identity_provider_id, types, [type | cleared_types])
  end

  defp clear_identity_provider_templates_cache_key(identity_provider_id, type, cleared_types) do
    if type in cleared_types do
      :ok
    else
      Boruta.Cache.delete({__MODULE__, :identity_provider_template, identity_provider_id, type})
    end
  end

  defp normalize_template_type(type) when is_binary(type) do
    Enum.find([:layout | Template.template_types()], &(Atom.to_string(&1) == type)) || type
  end

  defp normalize_template_type(type), do: type

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Accounts.Ldap
  alias BorutaIdentity.IdentityProviders.Backend

  def list_backends do
    Repo.all(Backend)
  end

  @decorate cacheable(key: {__MODULE__, :backend, id}, cache: Boruta.Cache)
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
    :ok = Boruta.Cache.delete({__MODULE__, :backend, backend.id})

    if backend.is_default do
      :ok = Boruta.Cache.delete({Backend, :default})
    end

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
    :ok = Boruta.Cache.delete({__MODULE__, :backend, backend_id})

    if backend.is_default do
      :ok = Boruta.Cache.delete({Backend, :default})
    end

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
    :ok = Boruta.Cache.delete({__MODULE__, :backend, backend.id})

    if backend.is_default do
      :ok = Boruta.Cache.delete({Backend, :default})
    end

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
