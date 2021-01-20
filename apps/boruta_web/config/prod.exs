use Mix.Config

config :boruta_web, BorutaWeb.Endpoint,
  http: [:inet6, port: System.get_env("PORT") || 4000],
  url: [host: "boruta.local"],
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
