import Config

config :boruta_gateway,
  ecto_repos: [BorutaGateway.Repo, BorutaAuth.Repo],
  repo_backend: System.get_env("BORUTA_GATEWAY_BACKEND", "postgres")

config :boruta_gateway, BorutaGateway.Repo,
  path:
    System.get_env(
      "BORUTA_GATEWAY_MNESIA_DIR",
      Path.expand("../../../tmp/boruta_gateway_mnesia", __DIR__)
    )

config :logger, level: :info

import_config "#{Mix.env()}.exs"
