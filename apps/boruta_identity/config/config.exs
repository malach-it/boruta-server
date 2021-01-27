# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :boruta_identity,
  ecto_repos: [BorutaIdentity.Repo]

# Configures the endpoint
config :boruta_identity, BorutaIdentityWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "PiNxaP4F3pGwd3+oZDOqkE3RybRy90pfFiVc1why+rDqkNyhey/0dUBsts4PiDjJ",
  render_errors: [view: BorutaIdentityWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BorutaIdentity.PubSub,
  live_view: [signing_salt: "9q0RPs/i"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
