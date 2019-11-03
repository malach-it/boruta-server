defmodule Boruta.Oauth.AccessTokens do
  @moduledoc """
  Access token context
  """

  @callback get_by(
    [value: String.t()] |
    [refresh_token: String.t()]
  ) :: token :: Boruta.Oauth.Token.t() | nil

  @callback create(params :: %{
    :client => Boruta.Oauth.Client.t(),
    optional(:resource_owner) => struct(),
    optional(:redirect_uri) => String.t(),
    :scope => String.t(),
    optional(:state) => String.t()
  }, options :: [
    refresh_token: boolean()
  ]) :: token :: Boruta.Oauth.Token.t() | {:error, Ecto.Changeset.t()}
end
