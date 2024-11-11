defmodule BorutaFederation.Cache do
  use Nebulex.Cache,
    otp_app: :boruta_federation,
    adapter: Nebulex.Adapters.Replicated
end
