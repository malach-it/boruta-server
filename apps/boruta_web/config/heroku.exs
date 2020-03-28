use Mix.Config

config :boruta_web, BorutaWeb.Endpoint,
  http: [port: 4001],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Repo,
  ssl: true,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :boruta_web, BorutaWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
