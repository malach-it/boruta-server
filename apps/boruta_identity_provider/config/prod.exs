use Mix.Config

config :boruta_identity_provider, Boruta.Accounts,
  username: "${POSTGRES_USERNAME}",
  password: "${POSTGRES_PASSWORD}",
  database: "${POSTGRES_DATABASE}",
  hostname: "${POSTGRES_HOSTNAME}",
  port: "${POSTGRES_PORT}",
  pool_size: 20

config :borutaidentity_provider, Boruta.Accounts,
  secret_key_base: "${SECRET_KEY_BASE}"
