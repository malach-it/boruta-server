defmodule BorutaGateway.MnesiaRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :boruta_gateway,
    adapter: BorutaGateway.MnesiaAdapter
end
