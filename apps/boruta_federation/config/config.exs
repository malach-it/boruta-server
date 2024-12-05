import Config

config :boruta_federation,
  ecto_repos: [BorutaFederation.Repo],
  generators: [binary_id: true]

config :boruta_federation, BorutaFederationWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: BorutaWeb.PubSub

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
