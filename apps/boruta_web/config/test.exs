import Config

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: "averysecretkeybaseaverysecretkeybaseaverysecretkeybaseaverysecretkeybase"

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  http: [port: 4003],
  server: false,
  secret_key_base: "averysecretkeybaseaverysecretkeybaseaverysecretkeybaseaverysecretkeybase"

config :boruta_web, BorutaWeb.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_identity, BorutaIdentity.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_identity_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_auth, BorutaAuth.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_identity, Boruta.Accounts, secret_key_base: "secret"

config :boruta_web, BorutaWeb.Authorization,
  oauth2: [
    client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e20",
    client_secret: "777",
    site: "http://localhost:7778"
  ]

config :logger, level: :warn

config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: []],
      connect: {:net_kernel, :connect_node, []},
      disconnect: {:erlang, :disconnect_node, []},
      list_nodes: {:erlang, :nodes, [:connected]},
    ]
  ]
