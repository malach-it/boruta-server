{:ok, user} =
  BorutaIdentity.Accounts.User.changeset(%BorutaIdentity.Accounts.User{}, %{
    email: "test@test.test",
    password: "passwordes",
    confirm_password: "passwordes"
  })
  |> BorutaIdentity.Repo.insert()

scopes = [
  %{name: "users:manage:all"},
  %{name: "clients:manage:all"},
  %{name: "scopes:manage:all"},
  %{name: "upstreams:manage:all"}
]

scopes
|> Enum.map(fn (scope) ->
  {:ok, scope} = BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{user_id: user.id, name: scope.name})
  scope
end)
