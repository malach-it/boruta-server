{:ok, user} = BorutaIdentityProvider.Accounts.User.changeset(%BorutaIdentityProvider.Accounts.User{}, %{
  email: "test@test.test",
  password: "passwordes",
  confirm_password: "passwordes"
})
|> BorutaIdentityProvider.Repo.insert()

scopes = [
  %{name: "users:manage:all"},
  %{name: "clients:manage:all"},
  %{name: "scopes:manage:all"}
]

scopes
|> Enum.map(fn (scope) ->
  {:ok, scope} = BorutaIdentityProvider.Repo.insert(%BorutaIdentityProvider.Accounts.UserAuthorizedScope{user_id: user.id, name: scope.name})
  scope
end)
