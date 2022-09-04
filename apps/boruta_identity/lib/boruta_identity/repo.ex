defmodule BorutaIdentity.Repo do
  use Ecto.Repo,
    otp_app: :boruta_identity,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 12

  def set_limit(conn) do
    Postgrex.query(conn, "SELECT set_limit($1)", [0.15])
  end
end
