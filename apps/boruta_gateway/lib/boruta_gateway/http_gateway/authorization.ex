defmodule BorutaGateway.HttpGateway.Authorization do
  @moduledoc false

  defdelegate authorize(payload, method, upstream), to: BorutaGateway.Authorization
end
