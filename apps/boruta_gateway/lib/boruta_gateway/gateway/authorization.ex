defmodule BorutaGateway.Gateway.Authorization do
  @moduledoc false

  alias Boruta.Oauth
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token
  alias BorutaGateway.Upstreams.Upstream

  def authorize(_authorization_header, _method, %Upstream{authorize: false}) do
    {:ok, nil}
  end

  def authorize(payload, method, upstream) do
    with [_, authorization_header] <- Regex.run(~r{[A|a]uthorization\: ([^\r]+)}, payload),
         [_header, value] <- Regex.run(~r/[B|b]earer (.+)/, authorization_header),
         {:ok, %Token{scope: scope} = token} <- Oauth.Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, upstream.required_scopes, method) do
      {:ok, token}
    else
      {:error, "required scopes are not present."} ->
        {:forbidden, upstream.error_content_type, upstream.forbidden_response}

      _error ->
        {:unauthorized, upstream.error_content_type, upstream.unauthorized_response}
    end
  end

  defp validate_scopes(_scope, required_scopes, _method) when required_scopes == %{},
    do: {:ok, []}

  defp validate_scopes(scope, required_scopes, method) do
    scopes = Scope.split(scope)
    default_scopes = Map.get(required_scopes, "*", [:not_authorized])

    case Enum.empty?(Map.get(required_scopes, method, default_scopes) -- scopes) do
      true -> {:ok, scopes}
      false -> {:error, "required scopes are not present."}
    end
  end
end
