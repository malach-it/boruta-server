import Config

config :boruta_gateway,
  ecto_repos: [BorutaGateway.Repo, BorutaAuth.Repo]

import_config "#{Mix.env()}.exs"
