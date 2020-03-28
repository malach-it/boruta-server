use Mix.Config

config :boruta_gateway,
  port: String.to_integer(System.get_env("PORT") || "4000")

config :boruta_gateway, BorutaGateway.Repo,
  ssl: true,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
