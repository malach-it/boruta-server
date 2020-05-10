# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

# TODO remove BorutaIdentityProvider.Repo dependency
config :boruta,
  ecto_repos: [Boruta.Repo, BorutaIdentityProvider.Repo]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
