defmodule BorutaGateway.Authorization.OauthBearer do
  @moduledoc false
  @behaviour BorutaGateway.Authorization
  import BorutaGateway.Authorization.Helpers
  alias Boruta.Oauth
  alias Boruta.Oauth.{Scope, Token}

  def authorize(payload, method, upstream, _scheme) do
    with {:ok, value} <- bearer_token(payload),
         {:ok, %Token{scope: scope} = token} <-
           Oauth.Authorization.AccessToken.authorize(value: value),
         {:ok, _scopes} <- validate_scopes(Scope.split(scope), upstream.required_scopes, method) do
      {:ok, token}
    else
      {:error, "required scopes are not present."} ->
        forbidden(upstream)

      _error ->
        unauthorized(upstream, nil)
    end
  end

  defp bearer_token(payload) do
    case Regex.run(~r{(?:^|\r\n)authorization\s*:\s*bearer\s+([^\r\n]+)}i, payload) do
      [_, value] -> {:ok, String.trim(value)}
      nil -> :error
    end
  end
end
