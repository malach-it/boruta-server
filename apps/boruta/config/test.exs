# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# Configure your database
config :boruta, Boruta.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta, Boruta.Oauth,
  expires_in: %{
    access_token: 24 * 3600,
    authorization_code: 60
  },
  secret_key_base: "secret",
  resource_owner: %{
    schema: Boruta.Coherence.User
  }
