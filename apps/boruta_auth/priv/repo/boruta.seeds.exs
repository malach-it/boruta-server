import Ecto.Changeset

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "scopes:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "clients:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "upstreams:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "users:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "relying-parties:manage:all"
  },
  on_conflict: :nothing
)

BorutaAuth.Repo.insert(
  %Boruta.Ecto.Scope{
    name: "instances:manage:user"
  },
  on_conflict: :nothing
)

%Boruta.Ecto.Client{}
|> Boruta.Ecto.Client.create_changeset(%{
  secret: System.get_env("BORUTA_ADMIN_CLIENT_SECRET", "777"),
  id: System.get_env("BORUTA_ADMIN_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20"),
  redirect_uris: [
    "#{System.get_env("VUE_APP_BORUTA_BASE_URL", "http://localhost:4002")}/oauth-callback"
  ],
  access_token_ttl: 3600,
  authorization_code_ttl: 60,
  authorize_scope: true,
  authorized_scopes: BorutaAuth.Repo.all(Boruta.Ecto.Scope) |> Enum.map(&Map.from_struct/1)
})
|> BorutaAuth.Repo.insert()

BorutaGateway.Repo.insert(
  %BorutaGateway.Upstreams.Upstream{
    scheme: "http",
    host: "localhost",
    port: 4001,
    uris: ["/"]
  },
  on_conflict: :nothing
)

BorutaIdentity.RelyingParties.create_relying_party(%{
  name: "Default",
  registrable: true
})

{:ok, user} = BorutaIdentity.Accounts.User.registration_changeset(%BorutaIdentity.Accounts.User{}, %{
  email: System.get_env("ADMIN_EMAIL", "test@test.test"),
  password: System.get_env("ADMIN_PASSWORD", "passwordesat")
}) |> BorutaIdentity.Repo.insert()

scopes =
  [
    "users:manage:all",
    "clients:manage:all",
    "scopes:manage:all",
    "upstreams:manage:all",
    "relying-parties:manage:all",
    "instances:manage:user"
  ]
  |> Enum.map(fn scope_name ->
    BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
      name: scope_name,
      user_id: user.id
    })
  end)
