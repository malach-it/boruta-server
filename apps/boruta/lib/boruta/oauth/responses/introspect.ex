defmodule Boruta.Oauth.IntrospectResponse do
  @moduledoc """
  Introspect response
  """

  defstruct [
    active: nil,
    client_id: nil,
    username: nil,
    scope: nil,
    sub: nil,
    iss: "boruta",
    exp: nil,
    iat: nil
  ]

  alias Boruta.Oauth.IntrospectResponse
  alias Boruta.Oauth.Token

  def from_token(%Token{
    client: client,
    resource_owner: resource_owner,
    expires_at: expires_at,
    scope: scope,
    inserted_at: inserted_at
  }) do
    %IntrospectResponse{
      active: true,
      client_id: client.id,
      username: resource_owner && resource_owner.email,
      scope: scope,
      sub: resource_owner && resource_owner.id,
      iss: "boruta", # TODO change to hostname
      exp: expires_at,
      iat: DateTime.to_unix(inserted_at)
    }
  end

  def from_error(_), do: %IntrospectResponse{active: false}
end
