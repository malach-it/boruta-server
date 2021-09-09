use Mix.Config

config :boruta_identity, BorutaIdentity.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  http: [port: 4000, path: "/accounts"],
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

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/boruta_identity_web/(live|views)/.*(ex)$",
      ~r"lib/boruta_identity_web/templates/.*(eex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
