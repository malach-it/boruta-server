ExUnit.start()

Mox.defmock(BorutaIdentity.LdapRepoMock, for: BorutaIdentity.LdapRepo)

Ecto.Adapters.SQL.Sandbox.mode(BorutaAdmin.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaAuth.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaGateway.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaIdentity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaWeb.Repo, :manual)
