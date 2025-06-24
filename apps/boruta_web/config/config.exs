import Config

config :boruta_web,
  ecto_repos: [BorutaAuth.Repo, BorutaWeb.Repo]

config :boruta_web, BorutaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BorutaWeb.PubSub

config :mime, :types, %{
  "text/event-stream" => ["event-stream"],
  "application/jwt" => ["jwt"]
}

config :phoenix, :json_library, Jason

config :swoosh, :api_client, Swoosh.ApiClient.Finch

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ],
  max_ttl: [
    authorization_code: 600
  ],
  issuer: System.get_env("BORUTA_OAUTH_BASE_URL", "http://localhost:4000")

config :boruta_auth, BorutaAuth.LogRotate,
  max_retention_days: String.to_integer(System.get_env("MAX_LOG_RETENTION_DAYS", "60"))

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4,
                                 cleanup_interval_ms: 60_000 * 10]}

import_config "#{Mix.env()}.exs"
