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
  password_hashing_alg: Comeonin.Bcrypt,
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

config :authable,
  ecto_repos: [Boruta.Repo],
  repo: Boruta.Repo,
  expires_in: %{
    access_token: 3600,
    refresh_token: 24 * 3600,
    authorization_code: 300,
      session_token: 30 * 24 * 3600
    },
    grant_types: %{
      authorization_code: Authable.GrantType.AuthorizationCode,
      client_credentials: Authable.GrantType.ClientCredentials,
      password: Authable.GrantType.Password,
      refresh_token: Authable.GrantType.RefreshToken
    },
    auth_strategies: %{
      headers: %{
        "authorization" => [
          {~r/Basic ([a-zA-Z\-_\+=]+)/, Authable.Authentication.Basic},
          {~r/Bearer ([a-zA-Z\-_\+=]+)/, Authable.Authentication.Bearer},
        ],
        "x-api-token" => [
          {~r/([a-zA-Z\-_\+=]+)/, Authable.Authentication.Bearer}
        ]
      },
      query_params: %{
        "access_token" => Authable.Authentication.Bearer
      },
      sessions: %{
        "session_token" => Authable.Authentication.Session
      }
    },
    scopes: ~w(all restricted),
    renderer: Authable.Renderer.RestApi
