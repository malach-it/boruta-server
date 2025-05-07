import Config

config :boruta_admin,
  ecto_repos: [
    BorutaAdmin.Repo,
    BorutaAuth.Repo,
    BorutaIdentity.Repo,
    BorutaGateway.Repo,
    BorutaFederation.Repo,
    BorutaWeb.Repo
  ]

config :boruta_admin, BorutaAdminWeb.Endpoint,
  url: [
    host: "localhost",
    protocol_options: [idle_timeout: 3_600_000, inactivity_timeout: 3_600_000]
  ],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaAdminWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BorutaAdmin.PubSub,
  live_view: [signing_salt: "mtlt3we/"]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaWeb.ResourceOwners
  ],
  issuer: System.get_env("BORUTA_OAUTH_BASE_URL", "http://localhost:4000")

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
