import Config

config :boruta_identity,
  ecto_repos: [BorutaAuth.Repo, BorutaIdentity.Repo]

config :boruta_identity, BorutaIdentityWeb.Endpoint,
  url: [host: "localhost"],
  # url: [host: "localhost", path: "/accounts"],
  server: false,
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaIdentityWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BorutaIdentity.PubSub,
  live_view: [signing_salt: "9q0RPs/i"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ]

import_config "#{Mix.env()}.exs"
