defmodule BorutaAuth.Repo do
  use Ecto.Repo,
    otp_app: :boruta_auth,
    adapter: Ecto.Adapters.Postgres
end
