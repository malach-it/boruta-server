import Config

config :boruta_gateway,
  ecto_repos: [BorutaGateway.Repo, BorutaAuth.Repo]

config :logger, level: :info

import_config "#{Mix.env()}.exs"
