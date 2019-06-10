defmodule Boruta.Oauth.Introspect do
  @moduledoc """
  OAuth Introspect
  """

  # TODO defstruct

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectRequest
  alias Boruta.Oauth.Token

  @doc """
  Build an introspect response for the give `%IntrospectRequest{}`

  ## Examples
      iex> token(%IntrospectRequest{
        client_id: "client_id",
        client_secret: "client_secret",
        token: "token"
      })
      {:ok, %{"active" => false}}
  """
  @spec token(request :: %IntrospectRequest{client_id: String.t(), client_secret: String.t(), token: String.t()}) ::
  {:ok, response :: map()} | {:error , error :: Error.t()}
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
      {:error, %Error{error: :invalid_access_token}} ->
        {:ok, %{"active" => false}}
      {:error, %Error{} = error} -> {:error, error}
    end
  end
end
