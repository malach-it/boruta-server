# Since configuration is shared in umbrella projects, this file
# should only configure the :boruta application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

config :boruta, Boruta.Repo,
  username: "${POSTGRES_USERNAME}",
  password: "${POSTGRES_PASSWORD}",
  database: "${POSTGRES_DATABASE}",
  hostname: "${POSTGRES_HOSTNAME}",
  port: "${POSTGRES_PORT}",
  pool_size: 20

config :boruta, Boruta.Oauth,
  secret_key_base: "${SECRET_KEY_BASE}"
