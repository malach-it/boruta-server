# TODO set log level to debug
import Ecto.Changeset
import Ecto.Query

  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "scopes:manage:all"
    },
    on_conflict: :nothing
  )

  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "clients:manage:all"
    },
    on_conflict: :nothing
  )

  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "upstreams:manage:all"
    },
    on_conflict: :nothing
  )

  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "users:manage:all"
    },
    on_conflict: :nothing
  )

{:ok, instance_scope} =
  BorutaWeb.Repo.insert(
    %Boruta.Ecto.Scope{
      name: "instances:manage:user"
    },
    on_conflict: :nothing
  )

with {:ok, client} <- %Boruta.Ecto.Client{} |> Boruta.Ecto.Client.create_changeset(%{
  redirect_uris: [
    "#{System.get_env("VUE_APP_BORUTA_BASE_URL", "http://localhost:4002")}/oauth-callback"
  ],
  authorize_scope: false,
  access_token_ttl: 3600,
  authorization_code_ttl: 60
}) |> BorutaWeb.Repo.insert() do
  client |> change(%{
    secret: System.get_env("BORUTA_ADMIN_CLIENT_SECRET", "777"),
    id: System.get_env("BORUTA_ADMIN_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")
  }) |> BorutaWeb.Repo.update()
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

BorutaIdentity.Accounts.register_user(%{
  email: System.get_env("ADMIN_EMAIL", "test@test.test"),
  password: System.get_env("ADMIN_PASSWORD", "passwordesat")
})

scopes =
  [
    "users:manage:all",
    "clients:manage:all",
    "scopes:manage:all",
    "upstreams:manage:all",
    "instances:manage:user"
  ]
  |> Enum.map(fn scope_name ->
    BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
      name: scope_name,
      user_id: user.id
    })
  end)
