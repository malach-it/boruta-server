import Config

config :boruta_auth, BorutaAuth.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5"))

config :boruta_web, BorutaWeb.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 1

config :boruta_identity, BorutaIdentity.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_identity",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5")),
  after_connect: {BorutaIdentity.Repo, :set_limit, []}

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_gateway",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 1

config :boruta_admin, BorutaAdmin.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_admin",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 1

config :boruta_identity, Boruta.Accounts, secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_identity, BorutaIdentity.SMTP,
  adapter: Swoosh.Adapters.SMTP

config :boruta_gateway,
  port: System.get_env("BORUTA_GATEWAY_PORT") |> String.to_integer(),
  configuration_path: System.get_env("BORUTA_GATEWAY_CONFIGURATION_PATH", "config/example-configuration.yml"),
  server: true

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: System.get_env("BORUTA_OAUTH_PORT") |> String.to_integer()],
  url: [host: System.get_env("BORUTA_OAUTH_HOST")],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  url: [host: System.get_env("BORUTA_OAUTH_HOST"), path: "/accounts"],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_admin, BorutaAdminWeb.Endpoint,
  http: [
    port: System.get_env("BORUTA_ADMIN_PORT") |> String.to_integer(),
    protocol_options: [idle_timeout: 3_600_000, inactivity_timeout: 3_600_000]
  ],
  url: [host: System.get_env("BORUTA_ADMIN_HOST")],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Authorization,
  oauth2: [
    client_id: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID"),
    client_secret: System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_SECRET"),
    site: System.get_env("BORUTA_ADMIN_OAUTH_BASE_URL")
  ]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ],
  issuer: System.get_env("BORUTA_OAUTH_BASE_URL")

config :boruta_auth, BorutaAuth.LogRotate,
  max_retention_days: String.to_integer(System.get_env("MAX_LOG_RETENTION_DAYS", "60"))

if System.get_env("K8S_NAMESPACE") && System.get_env("K8S_SELECTOR") do
  config :libcluster,
    topologies: [
      k8s: [
        strategy: Cluster.Strategy.Kubernetes,
        config: [
          mode: :ip,
          kubernetes_ip_lookup_mode: :pods,
          kubernetes_node_basename: "boruta",
          kubernetes_selector: System.get_env("K8S_SELECTOR"),
          kubernetes_namespace: System.get_env("K8S_NAMESPACE"),
          polling_interval: 10_000
        ]
      ]
    ]
else
  config :libcluster,
    topologies: [
      example: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: []],
        connect: {:net_kernel, :connect_node, []},
        disconnect: {:erlang, :disconnect_node, []},
        list_nodes: {:erlang, :nodes, [:connected]}
      ]
    ]
end
