import Ecto.Changeset

{:ok, scopes_scope} = Boruta.Repo.insert(%Boruta.Scope{
 name: "scopes:manage:all"
})
{:ok, clients_scope} = Boruta.Repo.insert(%Boruta.Scope{
  name: "clients:manage:all"
})
{:ok, users_scope} = Boruta.Repo.insert(%Boruta.Scope{
  name: "users:manage:all"
})

%Boruta.Client{}
|> cast(%{
  id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
  secret: "777",
  redirect_uris: ["https://boruta.herokuapp.com/admin/oauth-callback"],
  authorize_scope: false
}, [:id, :secret, :redirect_uris, :authorize_scope])
|> Boruta.Repo.insert()

Boruta.Accounts.User.changeset(%Boruta.Accounts.User{}, %{
  email: "test@test.test",
  password: "passwordes",
  confirm_password: "passwordes"
})
|> put_assoc(:authorized_scopes, [clients_scope, scopes_scope, users_scope])
|> Boruta.Repo.insert()
