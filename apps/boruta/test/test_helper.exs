ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Boruta.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaIdentityProvider.Repo, :manual)

Mox.defmock(Boruta.Support.ResourceOwners, for: Boruta.Oauth.ResourceOwners)
