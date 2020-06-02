defmodule BorutaIdentityProvider.Repo do
  use Ecto.Repo,
    otp_app: :boruta_identity_provider,
    adapter: Ecto.Adapters.Postgres
end
