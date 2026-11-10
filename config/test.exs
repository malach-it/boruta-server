import Config

# Token administration joins OAuth and identity tables in the same database.
# Keep local defaults consistent with the shared database used in CI.
for {application, repo} <- [
      {:boruta_admin, BorutaAdmin.Repo},
      {:boruta_auth, BorutaAuth.Repo},
      {:boruta_gateway, BorutaGateway.PostgresRepo},
      {:boruta_identity, BorutaIdentity.Repo},
      {:boruta_web, BorutaWeb.Repo}
    ] do
  config application, repo, database: System.get_env("POSTGRES_DATABASE", "boruta_server_test")
end

# Print only warnings and errors during test
config :logger, level: :warning
