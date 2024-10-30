defmodule BorutaFederation.Repo do
  use Ecto.Repo,
    otp_app: :boruta_federation,
    adapter: Ecto.Adapters.Postgres
end
