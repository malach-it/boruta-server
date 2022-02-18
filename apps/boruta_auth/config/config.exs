use Mix.Config

config :boruta_auth,
  ecto_repos: [BorutaAuth.Repo]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ]

import_config "#{Mix.env()}.exs"
