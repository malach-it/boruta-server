# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

config :boruta,
  ecto_repos: [Boruta.Repo]

import_config "#{Mix.env()}.exs"
