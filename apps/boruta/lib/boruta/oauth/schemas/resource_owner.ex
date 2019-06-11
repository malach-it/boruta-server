defmodule Boruta.Oauth.ResourceOwner do
  @moduledoc """
  Resource owner behaviour
  """

  @doc """
  Check user password against password hash
  """
  @callback checkpw(password :: String.t(), password_hash :: String.t()) :: boolean()
end
