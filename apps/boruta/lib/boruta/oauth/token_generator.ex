defmodule Boruta.Oauth.TokenGenerator do
  @moduledoc """
  Behaviour to implement utilities to generate token value. This must be implemented in the module configured as `token_generator` set in `config.exs`
  """

  @doc """
  Generates a token value from token entity.
  """
  @callback generate(token :: Boruta.Oauth.Token.t()) :: value :: String.t()
end
