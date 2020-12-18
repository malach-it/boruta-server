use Mix.Config

config :boruta_gateway, BorutaGateway.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_gateway_dev",
  hostname: "localhost",
  pool_size: 10

config :boruta_gateway,
  port: 4000
