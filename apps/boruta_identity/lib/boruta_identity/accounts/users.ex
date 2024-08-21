defmodule BorutaIdentity.Accounts.Users do
  @moduledoc false

  import Ecto.Query

  alias Boruta.Ecto.Scopes
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Accounts.UserRole
  alias BorutaIdentity.Accounts.UserToken
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.BackendRole
  alias BorutaIdentity.Organizations.OrganizationUser
  alias BorutaIdentity.Repo

  @spec get_user_by_email(backend :: Backend.t(), email :: String.t()) :: user :: User.t() | nil
  def get_user_by_email(backend, email) when is_binary(email) do
    # TODO remove backend_user from domain
    case apply(
           Backend.implementation(backend),
           :get_user,
           [backend, %{email: email}]
         ) do
      {:ok, backend_user} ->
        apply(
          Backend.implementation(backend),
          :domain_user!,
          [backend_user, backend]
        )

      _ ->
        nil
    end
  end

  @spec get_user(id :: String.t()) :: user :: User.t() | nil
  def get_user(id) when is_binary(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        left_join: b in assoc(u, :backend),
        preload: [authorized_scopes: as, backend: b],
        where: u.id == ^id
      )
    )
  end

  def get_user(_), do: nil

  @doc """
  Gets the user with the given signed token.
  """
  @spec get_user_by_session_token(token :: String.t()) :: user :: User.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query) |> Repo.preload(:backend)
  end

  @spec get_user_scopes(user_id :: String.t()) :: user :: list(UserAuthorizedScope.t()) | nil
  def get_user_scopes(user_id) do
    scopes = Scopes.all()

    Repo.all(from(u in UserAuthorizedScope, where: u.user_id == ^user_id))
    |> Enum.map(fn user_scope ->
      Enum.find(scopes, fn %{id: id} -> id == user_scope.scope_id end)
    end)
    |> Enum.flat_map(fn
      %{id: id, name: name} -> [%Scope{id: id, name: name}]
      _ -> []
    end)
  end

  @spec get_user_roles(user_id :: String.t()) ::
          user :: list(BackendRole.t() | UserRole.t()) | nil
  def get_user_roles(user_id) do
    scopes = Scopes.all()

    (Repo.all(
       from(ur in UserRole,
         left_join: r in assoc(ur, :role),
         left_join: rs in assoc(r, :role_scopes),
         where: ur.user_id == ^user_id,
         preload: [role: {r, [role_scopes: rs]}]
       )
     ) ++
       Repo.all(
         from(br in BackendRole,
           left_join: b in assoc(br, :backend),
           left_join: r in assoc(br, :role),
           left_join: u in assoc(b, :users),
           left_join: rs in assoc(r, :role_scopes),
           where: u.id == ^user_id,
           preload: [role: {r, [role_scopes: rs]}]
         )
       ))
    |> Enum.uniq_by(fn %{role: role} -> role end)
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

  @spec get_user_organizations(user_id :: String.t()) :: user :: list(OrganizationUser.t()) | nil
  def get_user_organizations(user_id) do
    Repo.all(
      from(ou in OrganizationUser,
        left_join: o in assoc(ou, :organization),
        where: ou.user_id == ^user_id,
        preload: [organization: o]
      )
    )
    |> Enum.map(fn %{organization: organization} -> organization end)
  end

  @spec put_user_webauthn_challenge(user :: User.t()) ::
          {:ok, user :: User.t()} | {:error, changset :: Ecto.Changeset.t()}
  def put_user_webauthn_challenge(user) do
    user
    |> User.webauthn_challenge_changeset()
    |> Repo.update()
  end
end
