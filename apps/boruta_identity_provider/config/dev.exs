use Mix.Config

# Configure your database
config :boruta_identity_provider, BorutaIdentityProvider.Repo,
  username: "postgres",
  password: "postgres",
  database: "boruta_identity_provider_dev",
  hostname: "localhost",
  pool_size: 5

config :boruta_identity_provider, Boruta.Accounts,
  secret_key_base: "secret"

config :boruta, Boruta.Oauth,
  repo: BorutaIdentityProvider.Repo,
  contexts: [
    access_tokens: Boruta.Ecto.AccessTokens,
    clients: Boruta.Ecto.Clients,
    codes: Boruta.Ecto.Codes,
    resource_owners: BorutaIdentityProvider.ResourceOwners,
    scopes: Boruta.Ecto.Scopes
  ],
  expires_in: [
    authorization_code: 60,
    access_token: 3600
  ],
  token_generator: Boruta.TokenGenerator
