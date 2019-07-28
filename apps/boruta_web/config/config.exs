# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta_web application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# General application configuration
config :boruta_web,
  ecto_repos: [Boruta.Repo],
  generators: [context_app: :boruta, binary_id: true]

# Configures the endpoint
config :boruta_web, BorutaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Caq0kwgjLGwxoEVPOxUhEiZ3AG2nADaNYi+ceWh2RuAgKF6vv/FfwqM/P7cDcNrR",
  render_errors: [view: BorutaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BorutaWeb.PubSub, adapter: Phoenix.PubSub.PG2]

config :appsignal, :config,
  filter_parameters: ["password", "current_password", "password_confirmation", "client_secret"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

config :boruta_web, :pow,
  repo: Boruta.Repo,
  user: Boruta.Pow.User,
  # extensions: [PowEmailConfirmation, PowResetPassword],
  extensions: [PowResetPassword],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  routes_backend: BorutaWeb.Pow.Routes,
  mailer_backend: BorutaWeb.Pow.Mailer
