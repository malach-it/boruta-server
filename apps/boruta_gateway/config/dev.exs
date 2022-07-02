import Config

config :boruta_gateway, BorutaGateway.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_gateway_dev",
  hostname: "localhost",
  pool_size: 5

config :boruta_gateway,
  port: System.get_env("BORUTA_GATEWAY_PORT", "4002") |> String.to_integer()
