use Mix.Config

config :boruta, Boruta.Repo,
  username: "${POSTGRES_USERNAME}",
  password: "${POSTGRES_PASSWORD}",
  database: "${POSTGRES_DATABASE}",
  hostname: "${POSTGRES_HOSTNAME}",
  port: "${POSTGRES_PORT}",
  pool_size: 20
