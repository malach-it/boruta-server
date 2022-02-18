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
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5"))

config :boruta_identity, BorutaIdentity.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_identity_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5"))

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_gateway_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5"))

config :boruta_admin, BorutaAdmin.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_admin_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 1

config :boruta_identity, Boruta.Accounts, secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_identity, BorutaIdentity.Mailer,
  adapter: Swoosh.Adapters.Mailjet,
  secret: System.get_env("MAILJET_SECRET"),
  api_key: System.get_env("MAILJET_API_KEY")

config :boruta_gateway,
  port: String.to_integer(System.get_env("PORT") || "4000"),
  server: true

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: 4001],
  url: [host: System.get_env("BORUTA_OAUTH_HOST")],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  server: false,
  url: [host: System.get_env("BORUTA_OAUTH_HOST"), path: "/accounts"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_admin, BorutaAdminWeb.Endpoint,
  http: [port: 4002],
  url: [host: System.get_env("BORUTA_ADMIN_HOST")],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Authorization,
  oauth2: [
    client_id: System.get_env("ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20"),
    client_secret: System.get_env("ADMIN_OAUTH_CLIENT_SECRET", "777"),
    site: System.get_env("ADMIN_OAUTH_BASE_URL", "http://oauth.boruta.patatoid.fr")
  ]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ],
  issuer: "https://oauth.boruta.patatoid.fr"

config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :ip,
        kubernetes_ip_lookup_mode: :pods,
        kubernetes_node_basename: "boruta",
        kubernetes_selector: "app=boruta",
        kubernetes_namespace: System.get_env("K8S_NAMESPACE"),
        polling_interval: 10_000
      ]
    ]
  ]
