import Config

config :boruta_web, BorutaWeb.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_web",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 10

config :boruta_identity, BorutaIdentity.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_identity_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 10

config :boruta_gateway, BorutaGateway.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_gateway_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool_size: 10

config :boruta_identity, Boruta.Accounts,
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_gateway,
  port: String.to_integer(System.get_env("PORT") || "4000"),
  server: true

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: 4001],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
