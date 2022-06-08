defmodule BorutaIdentity.Repo do
  use Ecto.Repo,
    otp_app: :boruta_identity,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 24
end
