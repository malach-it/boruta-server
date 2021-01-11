use Mix.Config

config :boruta_identity,
  ecto_repos: [BorutaIdentity.Repo]

config :boruta, :pow,
  repo: BorutaIdentity.Repo,
  user: Boruta.Accounts.User,
  # extensions: [PowEmailConfirmation, PowResetPassword]
  extensions: [PowResetPassword]

config :boruta_identity, Boruta.Accounts,
  repo: BorutaIdentity.Repo

import_config "#{Mix.env()}.exs"
