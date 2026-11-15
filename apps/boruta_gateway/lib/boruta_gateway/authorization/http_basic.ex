defmodule BorutaGateway.Authorization.HttpBasic do
  @moduledoc false
  @behaviour BorutaGateway.Authorization
  import BorutaGateway.Authorization.Helpers
  alias Boruta.Oauth.{ResourceOwner, Scope}
  alias BorutaGateway.Upstreams.Upstream
  @basic_challenge ~s(Basic realm="Boruta gateway", charset="UTF-8")
  def authorize(payload, method, upstream, _scheme) do
    with {:ok, {username, password}} <- basic_credentials(payload),
         {:ok, %ResourceOwner{} = owner, scopes} <-
           authenticate_resource_owner(username, password),
         {:ok, required_scopes} <- validate_scopes(scopes, upstream.required_scopes, method),
         {:ok, token} <-
           maybe_create_basic_token(upstream, owner, required_scopes, {username, password}) do
      {:ok, {:basic_authorized, token}}
    else
      {:error, "required scopes are not present."} ->
        forbidden(upstream)

      _error ->
        unauthorized(upstream, @basic_challenge)
    end
  end

  defp maybe_create_basic_token(
         %Upstream{forward_basic_auth_token: false},
         _owner,
         _scopes,
         _credentials
       ),
       do: {:ok, nil}

  defp maybe_create_basic_token(
         %Upstream{forward_basic_auth_token: true},
         owner,
         scopes,
         credentials
       ) do
    with %Boruta.Oauth.Client{} = client <- Boruta.ClientsAdapter.public!() do
      BorutaGateway.BasicAccessTokens.get_or_create(
        %{client: client, resource_owner: owner, sub: owner.sub, scope: Enum.join(scopes, " ")},
        credentials
      )
    end
  end

  defp authenticate_resource_owner(username, password) do
    resource_owners = resource_owners()

    with module when is_atom(module) <- resource_owners,
         {:ok, %ResourceOwner{} = resource_owner} <- module.get_by(username: username),
         :ok <- module.check_password(resource_owner, password),
         :ok <- ResourceOwner.ensure_valid(resource_owner) do
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
    scopes
    |> Enum.flat_map(fn
      %Scope{name: name} when is_binary(name) -> [name]
      %{name: name} when is_binary(name) -> [name]
      name when is_binary(name) -> [name]
      _scope -> []
    end)
    |> Enum.uniq()
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
end
