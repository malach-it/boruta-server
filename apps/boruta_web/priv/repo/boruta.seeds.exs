import Ecto.Changeset

{:ok, scopes_scope} = BorutaWeb.Repo.insert(%Boruta.Ecto.Scope{
 name: "scopes:manage:all"
})
{:ok, clients_scope} = BorutaWeb.Repo.insert(%Boruta.Ecto.Scope{
  name: "clients:manage:all"
})
{:ok, upstreams_scope} = BorutaWeb.Repo.insert(%Boruta.Ecto.Scope{
  name: "upstreams:manage:all"
})
{:ok, users_scope} = BorutaWeb.Repo.insert(%Boruta.Ecto.Scope{
  name: "users:manage:all"
})

%Boruta.Ecto.Client{} |> cast(%{
  id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
  secret: "777",
  redirect_uris: ["http://localhost:4000/admin/oauth-callback"],
  authorize_scope: false,
  access_token_ttl: 3600,
  authorization_code_ttl: 60
}, [:id, :secret, :redirect_uris, :authorize_scope, :access_token_ttl, :authorization_code_ttl])
|> BorutaWeb.Repo.insert()

BorutaGateway.Repo.insert(%BorutaGateway.Upstreams.Upstream{
  scheme: "http",
  host: "localhost",
  port: 4001,
  uris: ["/"]
})

{:ok, user} =
  BorutaIdentityProvider.Accounts.User.changeset(%BorutaIdentityProvider.Accounts.User{}, %{
    email: "test@test.test",
    password: "passwordes",
    confirm_password: "passwordes"
  })
  |> BorutaIdentityProvider.Repo.insert()

scopes = [
  %{name: "users:manage:all"},
  %{name: "clients:manage:all"},
  %{name: "scopes:manage:all"},
  %{name: "upstreams:manage:all"}
]

scopes
|> Enum.map(fn (scope) ->
  {:ok, scope} = BorutaIdentityProvider.Repo.insert(%BorutaIdentityProvider.Accounts.UserAuthorizedScope{user_id: user.id, name: scope.name})
  scope
end)
