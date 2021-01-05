use Mix.Config

# Configure your database
config :boruta_identity, BorutaIdentity.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_dev",
  hostname: "localhost",
  pool_size: 5

config :boruta_identity, Boruta.Accounts,
  secret_key_base: "secret"

config :boruta, Boruta.Oauth,
  repo: BorutaIdentity.Repo,
  contexts: [
    access_tokens: Boruta.Ecto.AccessTokens,
    clients: Boruta.Ecto.Clients,
    codes: Boruta.Ecto.Codes,
    resource_owners: BorutaIdentity.ResourceOwners,
    scopes: Boruta.Ecto.Scopes
  ],
  expires_in: [
    authorization_code: 60,
    access_token: 3600
  ],
  token_generator: Boruta.TokenGenerator
