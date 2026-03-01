import Config

config :boruta_auth,
  ecto_repos: [BorutaAuth.Repo]

config :boruta, Boruta.Oauth,
  repo: BorutaAuth.Repo,
  contexts: [
    resource_owners: BorutaIdentity.ResourceOwners
  ],
  issuer: System.get_env("BORUTA_OAUTH_BASE_URL", "http://localhost:4000"),
  universal_did_auth: %{
    type: "bearer",
    token: "13c725e0-1375-40be-a567-648935571c54"
  }

config :boruta_auth, BorutaAuth.Scheduler,
  jobs: [
    {"@daily", {BorutaAuth.LogRotate, :rotate, []}}
  ]

config :boruta_auth, BorutaAuth.LogRotate,
  max_retention_days: String.to_integer(System.get_env("MAX_LOG_RETENTION_DAYS", "60"))

import_config "#{Mix.env()}.exs"
