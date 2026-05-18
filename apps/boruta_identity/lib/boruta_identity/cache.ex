defmodule BorutaIdentity.Cache do
  @moduledoc false

  use Nebulex.Cache,
    otp_app: :boruta_identity,
    adapter: Nebulex.Adapters.Replicated
end
