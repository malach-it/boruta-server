use Mix.Config

config :boruta_web,
  ecto_repos: [BorutaIdentity.Repo, BorutaWeb.Repo],
  generators: [context_app: :boruta, binary_id: true]

config :boruta_web, BorutaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: BorutaWeb.PubSub

config :mime, :types, %{
  "application/jwt" => ["jwt"]
}

config :phoenix, :json_library, Jason

config :swoosh, :api_client, Swoosh.ApiClient.Finch

config :boruta, Boruta.Oauth,
  repo: BorutaWeb.Repo,
  contexts: [
    resource_owners: BorutaWeb.ResourceOwners
  ]

import_config "#{Mix.env()}.exs"
