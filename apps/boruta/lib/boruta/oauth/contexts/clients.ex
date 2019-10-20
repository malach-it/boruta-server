defmodule Boruta.Oauth.Clients do
  @moduledoc """
  Client context
  """
  @callback get_by(
    [id: id :: String.t(), secret: String.t()] |
    [id: id :: String.t(), redirect_uri: String.t()]
  ) :: client :: Boruta.Oauth.Client.t() | nil
  @callback authorized_scopes(client :: Boruta.Oauth.Client.t()) :: list(Boruta.Oauth.Scope.t())
end
