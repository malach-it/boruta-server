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
    name: "profile",
    label: "Profile",
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
    name: "roles:manage:all",
    label: "Manage all roles"
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

client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")
client = case Boruta.Ecto.Admin.create_client(%{
    name: "Boruta administration panel",
    secret: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET", "777"),
    id: client_id,
    redirect_uris: [
      "#{System.get_env("BORUTA_ADMIN_BASE_URL", "http://localhost:4001")}/oauth-callback"
    ],
    access_token_ttl: 3600,
    authorization_code_ttl: 60,
    public_revoke: true
}) do
  {:ok, client} -> client
  {:error, _error} -> Boruta.Ecto.Admin.get_client!(client_id)
end

backend = BorutaIdentity.IdentityProviders.Backend.default!()

BorutaIdentity.IdentityProviders.create_identity_provider(%{
    name: "Default",
    registrable: true,
    backend_id: backend.id
})

identity_provider = case BorutaIdentity.IdentityProviders.create_identity_provider(%{
    name: "Boruta administration interface",
    registrable: false,
    backend_id: backend.id
}) do
  {:ok, identity_provider} -> identity_provider
  {:error, _error} ->
    BorutaIdentity.IdentityProviders.list_identity_providers()
  |> Enum.find(fn (%{name: name}) -> name == "Boruta administration interface" end)
end

BorutaIdentity.IdentityProviders.upsert_client_identity_provider(client.id, identity_provider.id)

email = System.get_env("BORUTA_ADMIN_EMAIL")
user = case BorutaIdentity.Accounts.Internal.User.registration_changeset(
    %BorutaIdentity.Accounts.Internal.User{},
    %{
      email: email,
      password: System.get_env("BORUTA_ADMIN_PASSWORD"),
      password_confirmation: System.get_env("BORUTA_ADMIN_PASSWORD"),
      confirmed_at: DateTime.utc_now()
    },
    %{backend: backend}
  )
  |> BorutaIdentity.Repo.insert() do
  {:ok, user} ->
    user
  {:error, _error} ->
    BorutaIdentity.Repo.get_by(BorutaIdentity.Accounts.Internal.User, email: email)
end

user = BorutaIdentity.Accounts.Internal.domain_user!(user, backend)

Boruta.Ecto.Admin.get_scopes_by_names([
  "users:manage:all",
  "clients:manage:all",
  "scopes:manage:all",
  "roles:manage:all",
  "upstreams:manage:all",
  "identity-providers:manage:all",
  "configuration:manage:all",
  "logs:read:all"
])
|> Enum.map(fn %{id: scope_id} ->
  %BorutaIdentity.Accounts.UserAuthorizedScope{
    scope_id: scope_id,
    user_id: user.id
  } |> Ecto.Changeset.change()
  |> BorutaIdentity.Repo.insert(on_conflict: :nothing)
end)
