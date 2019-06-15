defmodule Boruta.TokenGenerator do
  @moduledoc false

  @behaviour Boruta.Oauth.TokenGenerator

  alias Boruta.Oauth.Token

  @impl Boruta.Oauth.TokenGenerator
  def generate(%Token{type: "access_token"}) do
    :crypto.strong_rand_bytes(64) |> Base.encode64 |> binary_part(0, 64)
  end
  def generate(%Token{type: "code"}) do
    :crypto.strong_rand_bytes(32) |> Base.encode64 |> binary_part(0, 32)
  end
end
