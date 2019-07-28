import Ecto.Changeset

{:ok, scopes_scope} = Boruta.Repo.insert(%Boruta.Oauth.Scope{
 name: "scopes:manage:all"
})
{:ok, clients_scope} = Boruta.Repo.insert(%Boruta.Oauth.Scope{
  name: "clients:manage:all"
})
{:ok, users_scope} = Boruta.Repo.insert(%Boruta.Oauth.Scope{
  name: "users:manage:all"
})

%Boruta.Oauth.Client{}
|> cast(%{
  id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
  secret: "777",
  redirect_uri: "http://localhost:4000/admin/oauth-callback",
  authorize_scope: true
}, [:id, :secret, :redirect_uri, :authorize_scope])
|> put_assoc(:authorized_scopes, [clients_scope, scopes_scope, users_scope])
|> Boruta.Repo.insert()
