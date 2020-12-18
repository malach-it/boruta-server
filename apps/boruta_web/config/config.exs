use Mix.Config

config :boruta_web,
  ecto_repos: [BorutaWeb.Repo, BorutaIdentityProvider.Repo, BorutaGateway.Repo],
  generators: [context_app: :boruta, binary_id: true]

config :boruta_web, BorutaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BorutaWeb.PubSub, adapter: Phoenix.PubSub.PG2]

config :boruta_web, :pow,
  repo: BorutaIdentityProvider.Repo,
  user: BorutaIdentityProvider.Accounts.User,
  # extensions: [PowEmailConfirmation, PowResetPassword],
  extensions: [PowResetPassword],
  controller_callbacks: BorutaWeb.Pow.Phoenix.ControllerCallbacks,
  routes_backend: BorutaWeb.Pow.Routes,
  mailer_backend: BorutaWeb.Pow.Mailer,
  web_module: BorutaWeb

config :phoenix, :json_library, Jason

config :boruta, Boruta.Oauth,
  repo: BorutaWeb.Repo,
  contexts: [
    resource_owners: BorutaWeb.ResourceOwners
  ]

import_config "#{Mix.env()}.exs"
