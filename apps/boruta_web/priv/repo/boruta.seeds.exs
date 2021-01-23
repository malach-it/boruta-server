# TODO set log level to debug
import Ecto.Changeset

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

%Boruta.Ecto.Client{}
|> cast(
  %{
    id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
    secret: "777",
    redirect_uris: [
      "http://admin.boruta.patatoid.fr/admin/oauth-callback",
      "http://boruta.local/admin/oauth-callback",
      "http://localhost:4000/admin/oauth-callback",
      "http://localhost:4001/admin/oauth-callback",
      "https://boruta.herokuapp.com/admin/oauth-callback"
    ],
    authorize_scope: false,
    access_token_ttl: 3600,
    authorization_code_ttl: 60
  },
  [:id, :secret, :redirect_uris, :authorize_scope, :access_token_ttl, :authorization_code_ttl]
)
|> BorutaWeb.Repo.insert(on_conflict: :nothing)

BorutaGateway.Repo.insert(
  %BorutaGateway.Upstreams.Upstream{
    scheme: "http",
    host: "localhost",
    port: 4001,
    uris: ["/"]
  },
  on_conflict: :nothing
)

{:ok, user} = BorutaIdentity.Accounts.User.changeset(%BorutaIdentity.Accounts.User{}, %{
    email: "test@test.test",
    password: "passwordes",
    confirm_password: "passwordes"
  }) |> BorutaIdentity.Repo.insert()

scopes = [
  %{name: "users:manage:all"},
  %{name: "clients:manage:all"},
  %{name: "scopes:manage:all"},
  %{name: "upstreams:manage:all"}
]

scopes |> Enum.map(fn scope ->
  {:ok, scope} = BorutaIdentity.Repo.insert(
      %BorutaIdentity.Accounts.UserAuthorizedScope{user: user, name: scope.name},
      on_conflict: :nothing
    )

  scope
end)
