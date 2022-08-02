BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "openid",
    label: "OpenID Connect capabilities",
    public: true
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "email",
    label: "Email",
    public: true
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "scopes:manage:all",
    label: "Manage all scopes"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "clients:manage:all",
    label: "Manage all clients"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "upstreams:manage:all",
    label: "Manage all upstreams"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "users:manage:all",
    label: "Manage all users"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "identity-providers:manage:all",
    label: "Manage all identity providers"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "configuration:manage:all",
    label: "Manage all configuration"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "logs:read:all",
    label: "Read all logs"
  },
  on_conflict: :nothing
)

{:ok, client} =
  Boruta.Ecto.Admin.create_client(%{
    name: "Boruta administration panel",
    secret: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", "777"),
    id: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20"),
    redirect_uris: [
      "#{System.get_env("BORUTA_ADMIN_BASE_URL", "http://localhost:4001")}/oauth-callback"
    ],
    access_token_ttl: 3600,
    authorization_code_ttl: 60,
    public_revoke: true
  })

{:ok, identity_provider} =
  BorutaIdentity.IdentityProviders.create_identity_provider(%{
    name: "Default",
    registrable: true
  })

BorutaIdentity.IdentityProviders.upsert_client_identity_provider(client.id, identity_provider.id)

{:ok, user} =
  BorutaIdentity.Accounts.Internal.User.registration_changeset(
    %BorutaIdentity.Accounts.Internal.User{},
    %{
      email: System.get_env("BORUTA_ADMIN_EMAIL"),
      password: System.get_env("BORUTA_ADMIN_PASSWORD"),
      password_confirmation: System.get_env("BORUTA_ADMIN_PASSWORD"),
      confirmed_at: DateTime.utc_now()
    }
  )
  |> BorutaIdentity.Repo.insert()

user = BorutaIdentity.Accounts.Internal.domain_user!(user)

Boruta.Ecto.Admin.get_scopes_by_names([
  "users:manage:all",
  "clients:manage:all",
  "scopes:manage:all",
  "upstreams:manage:all",
  "identity-providers:manage:all",
  "configuration:manage:all",
  "logs:read:all"
])
|> Enum.map(fn %{id: scope_id} ->
  BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
    scope_id: scope_id,
    user_id: user.id
  })
end)
