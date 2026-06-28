import Config

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 5

config :boruta_gateway,
  server: System.get_env("BORUTA_GATEWAY_SERVER", "true") == "true",
  sidecar_server: System.get_env("BORUTA_GATEWAY_SIDECAR", "true") == "true",
  proxy_server: System.get_env("BORUTA_GATEWAY_PROXY_SERVER", "true") == "true",
  https_proxy_server: System.get_env("BORUTA_GATEWAY_HTTPS_PROXY_SERVER", "true") == "true",
  https_server: System.get_env("BORUTA_GATEWAY_HTTPS_SERVER", "false") == "true",
  sidecar_https_server: System.get_env("BORUTA_GATEWAY_SIDECAR_HTTPS_SERVER", "false") == "true",
  https_verify_client_certificate:
    System.get_env("BORUTA_GATEWAY_HTTPS_VERIFY_CLIENT_CERTIFICATE", "false") == "true",
  sidecar_https_verify_client_certificate:
    System.get_env("BORUTA_GATEWAY_SIDECAR_HTTPS_VERIFY_CLIENT_CERTIFICATE", "false") == "true",
  port: System.get_env("BORUTA_GATEWAY_PORT", "8083") |> String.to_integer(),
  sidecar_port: System.get_env("BORUTA_GATEWAY_SIDECAR_PORT", "8084") |> String.to_integer(),
  proxy_port: System.get_env("BORUTA_GATEWAY_PROXY_PORT", "5555") |> String.to_integer(),
  https_proxy_port:
    System.get_env("BORUTA_GATEWAY_HTTPS_PROXY_PORT", "4444") |> String.to_integer(),
  https_port: System.get_env("BORUTA_GATEWAY_HTTPS_PORT", "8043") |> String.to_integer(),
  sidecar_https_port:
    System.get_env("BORUTA_GATEWAY_SIDECAR_HTTPS_PORT", "8044") |> String.to_integer(),
  num_acceptors: System.get_env("BORUTA_GATEWAY_ACCEPTORS", "8") |> String.to_integer()

config :boruta_gateway,
  kubernetes_ingress_controller: false,
  kubernetes_namespace: nil,
  kubernetes_ingress_class: nil,
  kubernetes_node_name: "global",
  kubernetes_poll_interval: 10_000
