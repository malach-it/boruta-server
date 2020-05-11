import Ecto.Changeset

{:ok, user} = BorutaIdentityProvider.Accounts.User.changeset(%BorutaIdentityProvider.Accounts.User{}, %{
  email: "test@test.test",
  password: "passwordes",
  confirm_password: "passwordes"
})
|> BorutaIdentityProvider.Repo.insert()

Boruta.Repo.all(Boruta.Ecto.Scope)
         |> Enum.map(fn (scope) ->
           {:ok, scope} = BorutaIdentityProvider.Repo.insert(%BorutaIdentityProvider.Accounts.UserAuthorizedScope{user_id: user.id, scope_id: scope.id})
           scope
         end)
