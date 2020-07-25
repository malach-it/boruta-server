defmodule BorutaWeb.Repo do
  use Ecto.Repo,
    otp_app: :boruta_web,
    adapter: Ecto.Adapters.Postgres
end
