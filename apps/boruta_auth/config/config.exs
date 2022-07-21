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

import_config "#{Mix.env()}.exs"
