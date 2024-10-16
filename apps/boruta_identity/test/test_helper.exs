ExUnit.start()

Mox.defmock(BorutaIdentity.LdapRepoMock, for: BorutaIdentity.LdapRepo)

Ecto.Adapters.SQL.Sandbox.mode(BorutaIdentity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaAuth.Repo, :manual)

Logger.remove_backend(:console)
