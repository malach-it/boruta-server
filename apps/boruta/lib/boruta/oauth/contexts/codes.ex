defmodule Boruta.Oauth.Codes do
  @moduledoc """
  Code context
  """
  @callback get_by(
    params :: [value: String.t(), redirect_uri: String.t()]
  ) :: token :: Boruta.Oauth.Token | nil
  @callback create(params :: %{
    :client => Boruta.Oauth.Client.t(),
    :resource_owner => struct(),
    :redirect_uri => String.t(),
    :scope => String.t(),
    :state => String.t()
  }) :: code :: Boruta.Oauth.Token.t() | {:error, Ecto.Changeset.t()}
end
