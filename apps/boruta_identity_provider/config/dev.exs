use Mix.Config

# Configure your database
config :boruta_identity_provider, BorutaIdentityProvider.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_provider_dev",
  hostname: "localhost",
  pool_size: 5
