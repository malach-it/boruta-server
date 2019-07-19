# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Boruta.Repo.insert!(%Boruta.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Boruta.Repo.insert(%Boruta.Oauth.Client{
#   id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
#   secret: "777",
#   redirect_uri: "http://redirect.uri"
# })

{:ok, scopes_scope} = Boruta.Repo.insert(%Boruta.Oauth.Scope{
 name: "scopes:manage:all"
})
{:ok, clients_scope} = Boruta.Repo.insert(%Boruta.Oauth.Scope{
  name: "clients:manage:all"
})
Boruta.Repo.insert(%Boruta.Oauth.Client{
  id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
  secret: "777",
  redirect_uri: "https://boruta.herokuapp.com/admin",
  authorize_scope: true,
  authorized_scopes: [clients_scope, scopes_scope]
})
