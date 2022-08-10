import Config

config :boruta_auth,
  ecto_repos: [BorutaAuth.Repo]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ]

config :boruta_auth, BorutaAuth.Scheduler,
  jobs: [
    {"@daily", {BorutaAuth.LogRotate, :rotate, []}}
  ]

config :boruta_auth, BorutaAuth.LogRotate,
  max_retention_days: String.to_integer(System.get_env("MAX_LOG_RETENTION_DAYS", "60"))

import_config "#{Mix.env()}.exs"
