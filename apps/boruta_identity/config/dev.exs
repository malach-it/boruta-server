import Config

config :boruta_identity, BorutaIdentity.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 5,
  after_connect: {BorutaIdentity.Repo, :set_limit, []}

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  http: [port: System.get_env("BORUTA_OAUTH_PORT", "4000") |> String.to_integer(), path: "/accounts"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  server: false

config :boruta_identity, BorutaIdentity.SMTP,
  adapter: Swoosh.Adapters.SMTP

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
