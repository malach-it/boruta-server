use Mix.Config

config :boruta_identity_provider,
  ecto_repos: [BorutaIdentityProvider.Repo]

config :boruta, :pow,
  repo: Boruta.Repo,
  user: Boruta.Accounts.User,
  # extensions: [PowEmailConfirmation, PowResetPassword]
  extensions: [PowResetPassword]

config :boruta_identity_provider, Boruta.Accounts,
  repo: BorutaIdentityProvider.Repo

import_config "#{Mix.env()}.exs"
