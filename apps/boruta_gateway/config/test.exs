import Config

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_gateway_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_auth, BorutaAuth.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_auth_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :boruta_gateway,
  server: true,
  sidecar_server: true,
  proxy_server: false,
  https_proxy_server: false,
  https_server: false,
  sidecar_https_server: false,
  https_verify_client_certificate: false,
  sidecar_https_verify_client_certificate: false,
  port: 7777,
  sidecar_port: 7778,
  proxy_port: 5555,
  https_proxy_port: 4444,
  https_port: 7443,
  sidecar_https_port: 7444,
  num_acceptors: 8,
  kubernetes_ingress_controller: false,
  kubernetes_namespace: nil,
  kubernetes_ingress_class: nil,
  kubernetes_node_name: "global",
  kubernetes_poll_interval: 10_000
