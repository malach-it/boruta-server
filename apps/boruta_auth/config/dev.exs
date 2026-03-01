import Config

config :boruta_identity, BorutaIdentity.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost"

config :boruta_auth, BorutaAuth.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DATABASE") || "boruta_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost"

config :boruta, Boruta.Oauth,
  universal_did_auth: %{
    type: "bearer",
    token: "13c725e0-1375-40be-a567-648935571c54"
  }
