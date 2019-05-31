# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

config :boruta,
  ecto_repos: [Boruta.Repo]

import_config "#{Mix.env()}.exs"

config :coherence,
  user_schema: Boruta.Coherence.User,
  repo: Boruta.Repo,
  module: Boruta,
  web_module: BorutaWeb,
  router: BorutaWeb.Router,
  password_hashing_alg: Boruta.Hash,
  messages_backend: BorutaWeb.Coherence.Messages,
  registration_permitted_attributes: [
    "email",
    "name",
    "password",
    "current_password",
    "password_confirmation"
  ],
  invitation_permitted_attributes: ["name", "email"],
  password_reset_permitted_attributes: [
    "reset_password_token",
    "password",
    "password_confirmation"
  ],
  session_permitted_attributes: ["remember", "email", "password"],
  email_from_name: "Your Name",
  email_from_email: "yourname@example.com",
  opts: [
    :authenticatable,
    :recoverable,
    :lockable,
    :trackable,
    :unlockable_with_token,
    :registerable
  ]

config :coherence, BorutaWeb.Coherence.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: "your api key here"

config :boruta,
  oauth: %{
    expires_in: %{
      access_token: 24 * 3600
    }
  }

