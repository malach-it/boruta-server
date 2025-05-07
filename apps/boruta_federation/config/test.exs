import Config

config :boruta_federation, BorutaFederation.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_federation, BorutaFederationWeb.Endpoint,
  http: [port: 4002],
  secret_key_base: "kX8AQucJ6V06IkkWlXxhcuXZye5LaIcqUaPdRuhIhCyD8zNKLXGoVZP0sR0IXz4V",
  server: false

config :logger, level: :warn
