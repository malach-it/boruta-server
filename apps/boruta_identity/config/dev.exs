import Config

config :boruta_identity, BorutaIdentity.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 5

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  http: [port: System.get_env("BORUTA_OAUTH_PORT", "4000") |> String.to_integer(), path: "/accounts"],
  url: [host: "localhost"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  server: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :boruta_identity, BorutaIdentity.Mailer,
  adapter: Swoosh.Adapters.Mailjet,
  secret: System.get_env("MAILJET_SECRET"),
  api_key: System.get_env("MAILJET_API_KEY")

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
