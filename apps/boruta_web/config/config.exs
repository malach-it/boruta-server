import Config

config :boruta_web,
  ecto_repos: [BorutaAuth.Repo, BorutaWeb.Repo]

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
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ]

import_config "#{Mix.env()}.exs"
