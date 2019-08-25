use Mix.Config

config :boruta_web, BorutaWeb.Endpoint,
  http: [:inet6, port: System.get_env("PORT") || 4000],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  instrumenters: [Appsignal.Phoenix.Instrumenter]
