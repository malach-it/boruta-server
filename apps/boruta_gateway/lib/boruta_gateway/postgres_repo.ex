defmodule BorutaGateway.PostgresRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :boruta_gateway,
    adapter: Ecto.Adapters.Postgres
end
