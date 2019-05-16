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
      refresh_token: Authable.GrantType.RefreshToken,
      implicit: Authable.GrantType.Implicit
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
