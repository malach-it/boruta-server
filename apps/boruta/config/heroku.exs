use Mix.Config

config :boruta, Boruta.Repo,
  ssl: true,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :boruta, Boruta.Oauth,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
