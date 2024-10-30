import Config

config :boruta_web, BorutaWeb.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 5

config :boruta_federation, BorutaFederationWeb.Endpoint,
  http: [port: System.get_env("BORUTA_OAUTH_PORT", "4000") |> String.to_integer()],
  debug_errors: true,
  code_reloader: true,
  check_origin: false

config :logger, :console, format: "[$level] $message\n"
