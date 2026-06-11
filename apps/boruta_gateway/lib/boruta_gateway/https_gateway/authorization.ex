defmodule BorutaGateway.HttpsGateway.Authorization do
  @moduledoc false

  alias Boruta.Oauth
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token
  alias BorutaGateway.Upstreams.Upstream

  @default_error_content_type "application/json"
  @default_forbidden_response Jason.encode!(%{
                                error: "FORBIDDEN",
                                message: "You are forbidden to access this resource."
                              })
  @default_unauthorized_response Jason.encode!(%{
                                   error: "UNAUTHORIZED",
                                   message: "You are unauthorized to access this resource."
                                 })

  def authorize(_authorization_header, _method, %Upstream{authorize: false}) do
    {:ok, nil}
  end

  def authorize(payload, method, upstream) do
    with {:ok, value} <- bearer_token(payload),
         {:ok, %Token{scope: scope} = token} <-
           Oauth.Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, upstream.required_scopes, method) do
      {:ok, token}
    else
      {:error, "required scopes are not present."} ->
        {:forbidden, upstream.error_content_type || @default_error_content_type,
         upstream.forbidden_response || @default_forbidden_response}

      _error ->
        {:unauthorized, upstream.error_content_type || @default_error_content_type,
         upstream.unauthorized_response || @default_unauthorized_response}
    end
  end

  defp bearer_token(payload) do
    case Regex.run(~r{(?:^|\r\n)authorization\s*:\s*bearer\s+([^\r\n]+)}i, payload) do
      [_, value] -> {:ok, String.trim(value)}
      nil -> :error
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
