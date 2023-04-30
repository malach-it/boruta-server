import Config

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 5

config :boruta_gateway,
  server: true,
  sidecar_server: true,
  port: System.get_env("BORUTA_GATEWAY_PORT", "5000") |> String.to_integer(),
  sidecar_port: System.get_env("BORUTA_GATEWAY_SIDECAR_PORT", "5001") |> String.to_integer()
