defmodule Boruta.Repo do
  use Ecto.Repo,
    otp_app: :boruta,
    adapter: Ecto.Adapters.Postgres
end
