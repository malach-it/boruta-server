# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :boruta_admin,
  ecto_repos: [BorutaAdmin.Repo]

# Configures the endpoint
config :boruta_admin, BorutaAdminWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "q4ceJF0AgNn2ayjJHAQRcmznUL4+BwS+8DnxhRVx5wRtinpN/nbCJa3HY4XT9L+l",
  render_errors: [view: BorutaAdminWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BorutaAdmin.PubSub,
  live_view: [signing_salt: "mtlt3we/"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
