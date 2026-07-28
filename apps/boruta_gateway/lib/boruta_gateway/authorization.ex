defmodule BorutaGateway.Authorization do
  @moduledoc false

  alias Boruta.Oauth
  alias Boruta.Oauth.ResourceOwner
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
  @basic_challenge ~s(Basic realm="Boruta gateway", charset="UTF-8")

  def authorize(_payload, _method, %Upstream{authorize: false}), do: {:ok, nil}

  def authorize(payload, method, %Upstream{authorization_type: "http_basic"} = upstream) do
    with {:ok, {username, password}} <- basic_credentials(payload),
         {:ok, %ResourceOwner{}, scopes} <-
           authenticate_resource_owner(username, password),
         {:ok, _scopes} <- validate_scopes(scopes, upstream.required_scopes, method) do
      {:ok, :basic_authorized}
    else
      {:error, "required scopes are not present."} ->
        forbidden(upstream)

      _error ->
        unauthorized(upstream, @basic_challenge)
    end
  end

  def authorize(payload, method, %Upstream{} = upstream) do
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

  defp authenticate_resource_owner(username, password) do
    resource_owners = resource_owners()

    with module when is_atom(module) <- resource_owners,
         {:ok, %ResourceOwner{} = resource_owner} <- module.get_by(username: username),
         :ok <- module.check_password(resource_owner, password) do
      {:ok, resource_owner, scope_names(module.authorized_scopes(resource_owner))}
    else
      _error -> :error
    end
  rescue
    _error -> :error
  catch
    _kind, _reason -> :error
  end

  defp resource_owners do
    case Application.fetch_env(:boruta_gateway, :basic_authorization_resource_owners) do
      {:ok, module} -> module
      :error -> Boruta.Config.resource_owners()
    end
  end

  defp scope_names(scopes) when is_list(scopes) do
    Enum.flat_map(scopes, fn
      %Scope{name: name} when is_binary(name) -> [name]
      %{name: name} when is_binary(name) -> [name]
      name when is_binary(name) -> [name]
      _scope -> []
    end)
  end

  defp scope_names(_scopes), do: []

  defp basic_credentials(payload) do
    with [_, encoded] <-
           Regex.run(~r{(?:^|\r\n)authorization\s*:\s*basic\s+([^\r\n]+)}i, payload),
         {:ok, decoded} <- Base.decode64(String.trim(encoded)),
         true <- String.valid?(decoded),
         [username, password] when username != "" <- String.split(decoded, ":", parts: 2) do
      {:ok, {username, password}}
    else
      _error -> :error
    end
  end

  defp bearer_token(payload) do
    case Regex.run(~r{(?:^|\r\n)authorization\s*:\s*bearer\s+([^\r\n]+)}i, payload) do
      [_, value] -> {:ok, String.trim(value)}
      nil -> :error
    end
  end

  defp validate_scopes(_scopes, required_scopes, _method) when required_scopes == %{},
    do: {:ok, []}

  defp validate_scopes(scopes, required_scopes, method) do
    default_scopes = Map.get(required_scopes, "*", [:not_authorized])

    case Enum.empty?(Map.get(required_scopes, method, default_scopes) -- scopes) do
      true -> {:ok, scopes}
      false -> {:error, "required scopes are not present."}
    end
  end

  defp forbidden(upstream) do
    {:forbidden, upstream.error_content_type || @default_error_content_type,
     upstream.forbidden_response || @default_forbidden_response}
  end

  defp unauthorized(upstream, challenge) do
    {:unauthorized, upstream.error_content_type || @default_error_content_type,
     upstream.unauthorized_response || @default_unauthorized_response, challenge}
  end
end
