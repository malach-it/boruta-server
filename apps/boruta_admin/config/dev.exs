import Config

config :boruta_admin, BorutaAdmin.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 1

config :boruta_admin, BorutaAdminWeb.Endpoint,
  http: [
    port: System.get_env("BORUTA_ADMIN_PORT", "4001") |> String.to_integer(),
    protocol_options: [idle_timeout: 3_600_000, inactivity_timeout: 3_600_000]
  ],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    npm: [
      "run",
      "build:watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/boruta_admin_web/{live,views}/.*(ex)$",
      ~r"lib/boruta_admin_web/templates/.*(eex)$"
    ]
  ]

config :logger, :console, level: :debug

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
