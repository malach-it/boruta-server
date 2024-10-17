ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(BorutaIdentity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaWeb.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(BorutaAuth.Repo, :manual)

Application.ensure_all_started(:bypass)

Logger.remove_backend(:console)
