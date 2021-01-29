{:ok, user} = BorutaIdentity.Accounts.register_user(%{email: "test@test.test", password: "passwordesat"})
scopes = [
  "users:manage:all",
  "clients:manage:all",
  "scopes:manage:all",
  "upstreams:manage:all"
] |> Enum.map(fn scope_name ->
  BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{name: scope_name, user_id: user.id})
end)
