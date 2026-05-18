defmodule BorutaIdentity.Cache do
  use Nebulex.Cache,
    otp_app: :boruta_identity,
    adapter: Nebulex.Adapters.Replicated
end
