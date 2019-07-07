defmodule Boruta.Oauth.TokenGenerator do
  @moduledoc """
  Behaviour to implement utilities to generate token value. This must be implemented in the module configured as `token_generator` set in `config.exs`
  """

  @doc """
  Generates a token value from token entity.
  """
  @callback generate(type :: :access_token | :refresh_token, token :: Boruta.Oauth.Token.t()) :: value :: String.t()
  @doc """
  Generates a secret from client entity.
  """
  @callback secret(client :: Boruta.Oauth.Client.t()) :: value :: String.t()
end
