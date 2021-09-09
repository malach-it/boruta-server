defmodule BorutaAdmin.Repo do
  use Ecto.Repo,
    otp_app: :boruta_admin,
    adapter: Ecto.Adapters.Postgres
end
