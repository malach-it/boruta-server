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
Boruta.Repo.insert(%Boruta.Oauth.Client{
  id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
  secret: "777",
  redirect_uri: "http://localhost:4000/admin"
})
