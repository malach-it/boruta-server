defmodule BorutaFederation.Cache do
  @moduledoc false

  use Nebulex.Cache,
    otp_app: :boruta_federation,
    adapter: Nebulex.Adapters.Replicated
end
