alias BorutaIdentity.Accounts.Internal
alias BorutaIdentity.Accounts.User

{:ok, user} =
  Internal.User.registration_changeset(%Internal.User{}, %{
    email: "identity@test.test",
    password: "passwordesat"
  })
  |> BorutaIdentity.Repo.insert()

{:ok, user} = BorutaIdentity.Repo.insert(%User{
  uid: user.id,
  username: user.email,
  provider: to_string(Internal)
})

[
  "users:manage:all",
  "clients:manage:all",
  "identity-providers:manage:all",
  "scopes:manage:all",
  "upstreams:manage:all"
]
|> Enum.map(fn scope_name ->
  BorutaIdentity.Repo.insert(%BorutaIdentity.Accounts.UserAuthorizedScope{
    name: scope_name,
    user_id: user.id
  })
end)
