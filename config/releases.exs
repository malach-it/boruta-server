import Config

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

config :boruta_identity, Boruta.Accounts, secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_gateway,
  port: String.to_integer(System.get_env("PORT") || "4000"),
  server: true

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: 4001],
  url: [host: System.get_env("BORUTA_ADMIN_HOST")],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :ip,
        kubernetes_ip_lookup_mode: :pods,
        kubernetes_node_basename: "boruta",
        kubernetes_selector: "app=boruta",
        kubernetes_namespace: "boruta-staging",
        polling_interval: 10_000
      ]
    ]
  ]
