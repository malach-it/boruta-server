use Mix.Config

config :boruta_web, BorutaWeb.Endpoint,
  http: [:inet6, port: System.get_env("PORT") || 4000],
  url: [scheme: "https", host: "boruta.herokuapp.com", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  cache_static_manifest: "priv/static/cache_manifest.json",
  instrumenters: [Appsignal.Phoenix.Instrumenter],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :boruta_web, BorutaWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
