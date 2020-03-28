use Mix.Config

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_gateway_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_gateway,
  port: 7777
