# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta_web application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# General application configuration
config :boruta_web,
  ecto_repos: [Boruta.Repo, BorutaIdentityProvider.Repo],
  generators: [context_app: :boruta, binary_id: true]

# Configures the endpoint
config :boruta_web, BorutaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BorutaWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

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
  resource_owner: %{
    adapter: BorutaIdentityProvider.ResourceOwners
  }

import_config "#{Mix.env()}.exs"
