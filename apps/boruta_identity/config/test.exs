import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :boruta_identity, BorutaIdentity.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  after_connect: {BorutaIdentity.Repo, :set_limit, []}

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  http: [port: 4002],
  server: false

config :boruta_identity, BorutaIdentity.SMTP,
  adapter: Swoosh.Adapters.Test

config :logger, level: :warn
