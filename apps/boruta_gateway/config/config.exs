use Mix.Config

config :boruta_gateway,
  ecto_repos: [BorutaGateway.Repo]

import_config "#{Mix.env()}.exs"
