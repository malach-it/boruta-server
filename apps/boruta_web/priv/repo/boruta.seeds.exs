# TODO set log level to debug
import Ecto.Changeset
import Ecto.Query

{:ok, scopes_scope} =
  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "scopes:manage:all"
    },
    on_conflict: :nothing
  )

{:ok, clients_scope} =
  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "clients:manage:all"
    },
    on_conflict: :nothing
  )

{:ok, upstreams_scope} =
  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "upstreams:manage:all"
    },
    on_conflict: :nothing
  )

{:ok, users_scope} =
  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "users:manage:all"
    },
    on_conflict: :nothing
  )

with {:ok, client} <- %Boruta.Ecto.Client{}
|> Boruta.Ecto.Client.create_changeset(%{
  redirect_uris: [
    "http://admin.boruta.patatoid.fr/admin/oauth-callback",
    "http://admin.boruta.local/admin/oauth-callback",
    "http://localhost:4000/admin/oauth-callback",
    "http://localhost:4001/admin/oauth-callback",
    "https://boruta.herokuapp.com/admin/oauth-callback"
  ],
  authorize_scope: false,
  access_token_ttl: 3600,
  authorization_code_ttl: 60
})
|> BorutaWeb.Repo.insert() do
  client
  |> change(%{
    secret: "777",
    id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20"
  })
  |> BorutaWeb.Repo.update()
end

BorutaGateway.Repo.insert(
  %BorutaGateway.Upstreams.Upstream{
    scheme: "http",
    host: "localhost",
    port: 4001,
    uris: ["/"]
  },
  on_conflict: :nothing
)

{:ok, user} =
  BorutaIdentity.Accounts.register_user(%{email: "test@test.test", password: "passwordesat"})

scopes =
  [
    "users:manage:all",
    "clients:manage:all",
    "scopes:manage:all",
    "upstreams:manage:all"
  ]
  |> Enum.map(fn scope_name ->
    BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
      name: scope_name,
      user_id: user.id
    })
  end)
