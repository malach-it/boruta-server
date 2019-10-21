defmodule Boruta.Oauth.Introspect do
  @moduledoc """
  OAuth Introspect
  """

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectRequest

  @doc """
  Build an introspect response for the given `IntrospectRequest`

  Note : Invalid tokens returns an error `{:error, %Error{error: :invalid_access_token, ...}}`. That must be rescued to return `%{"active" => false}` in application implementation.
  ## Examples
      iex> token(%IntrospectRequest{
        client_id: "client_id",
        client_secret: "client_secret",
        token: "token"
      })
      {:ok, %Token{...}}
  """
  @spec token(request :: %IntrospectRequest{
    client_id: String.t(),
    client_secret: String.t(),
    token: String.t()
  }) ::
  {:ok, response :: map()} |
  {:error , error :: Error.t()}
  def token(%IntrospectRequest{client_id: client_id, client_secret: client_secret, token: token}) do
    with {:ok, _client} <- Authorization.Base.client(id: client_id, secret: client_secret),
         {:ok, token} <- Authorization.Base.access_token(value: token) do
      {:ok, token}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end
end
