defmodule Boruta.Oauth.Revoke do
  @moduledoc """
  OAuth Revoke
  """

  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.RevokeRequest

  @doc """
  Build a revoke response for the given `RevokeRequest`
  ## Examples
      iex> token(%RevokeRequest{
        client_id: "client_id",
        client_secret: "client_secret",
        token: "token"
      })
      :ok
  """
  @spec token(request :: %RevokeRequest{
    client_id: String.t(),
    client_secret: String.t(),
    token: String.t()
  }) ::
  :ok |
  {:error , error :: Boruta.Oauth.Error.t()} |
  {:error , error :: String.t()}
  def token(%RevokeRequest{
    client_id: client_id,
    client_secret: client_secret,
    token: value,
    token_type_hint: token_type_hint
  }) do
    with {:ok, _client} <- Authorization.Client.authorize(id: client_id, secret: client_secret) do
      token = case token_type_hint do
        "refresh_token" ->
          with nil <- access_tokens().get_by(value: value),
               nil <- access_tokens().get_by(refresh_token: value) do
            nil
          end
        _ ->
          with nil <- access_tokens().get_by(refresh_token: value),
               nil <- access_tokens().get_by(value: value) do
            nil
          end
      end

      if token do
        with {:ok, _token} <- access_tokens().revoke(token) do
          :ok
        end
      else
        :ok # return :ok even for unexisting tokens
      end
    end
  end
end
