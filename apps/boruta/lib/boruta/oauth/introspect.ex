defmodule Boruta.Oauth.Introspect do
  @moduledoc """
  TODO OAuth Introspect
  """

  # TODO defstruct

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.IntrospectRequest
  alias Boruta.Oauth.Token

  def token(%IntrospectRequest{client_id: client_id, client_secret: client_secret, token: token}) do
    with {:ok, client} <- Authorization.Base.client(id: client_id, secret: client_secret),
         {:ok, %Token{
           resource_owner: resource_owner,
           expires_at: expires_at,
           scope: scope,
           inserted_at: inserted_at
         }} <- Authorization.Base.access_token(value: token) do
      {:ok, %{
        "active" => true,
        "client_id" => client.id,
        "username" => resource_owner && resource_owner.email,
        "scope" => scope,
        "sub" => resource_owner && resource_owner.id,
        "iss" => "boruta", # TODO change to hostname
        "exp" => expires_at,
        "iat" => DateTime.to_unix(inserted_at)
      }}
    else
      {_status, %{error: "invalid_access_token"}} ->
        {:ok, %{"active" => false}}
      error -> error
    end
  end
end
