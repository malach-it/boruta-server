defprotocol Boruta.Oauth.Authorization do
  @moduledoc """
  """

  @doc """
  Creates and returns a token for given request, depending of implementation.
  """
  # TODO type check implementations
  def token(request)
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ClientCredentialsRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.Token

  def token(%ClientCredentialsRequest{
    client_id: client_id,
    client_secret: client_secret,
    scope: scope
  }) do
    with {:ok, client} <- client(id: client_id, secret: client_secret),
         {:ok, scope} <- scope(scope: scope, against: %{client: client}) do
      # TODO rescue from creation errors
      access_tokens().create(%{
        client: client,
        scope: scope
      }, refresh_token: true)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.PasswordRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.PasswordRequest
  alias Boruta.Oauth.Token

  def token(%PasswordRequest{
    client_id: client_id,
    client_secret: client_secret,
    username: username,
    password: password,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, secret: client_secret),
         {:ok, resource_owner} <- resource_owner(username: username, password: password),
         {:ok, scope} <- scope(scope: scope, against: %{client: client, resource_owner: resource_owner}) do
      # TODO rescue from creation errors
      access_tokens().create(%{
        client: client,
        resource_owner: resource_owner,
        scope: scope,
      }, refresh_token: true)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.AuthorizationCodeRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.Token

  def token(%AuthorizationCodeRequest{
    client_id: client_id,
    code: code,
    redirect_uri: redirect_uri,
  }) do
    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, code} <- code(%{value: code, redirect_uri: redirect_uri}),
         {:ok, resource_owner} <- resource_owner(resource_owner: code.resource_owner) do
      # TODO rescue from creation errors
      access_tokens().create(%{
        client: client,
        resource_owner: resource_owner,
        scope: code.scope,
      }, refresh_token: true)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.TokenRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.TokenRequest
  alias Boruta.Oauth.Token

  def token(%TokenRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    resource_owner: resource_owner,
    state: state,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, resource_owner} <- resource_owner(resource_owner: resource_owner),
         {:ok, scope} <- scope(scope: scope, against: %{client: client, resource_owner: resource_owner}) do
      # TODO rescue from creation errors
      access_tokens().create(%{
        client: client,
        resource_owner: resource_owner,
        scope: scope,
        state: state,
      }, refresh_token: false)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.CodeRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [codes: 0]

  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Token

  def token(%CodeRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    resource_owner: resource_owner,
    state: state,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, resource_owner} <- resource_owner(resource_owner: resource_owner),
         {:ok, scope} <- scope(scope: scope, against: %{client: client}) do
      # TODO rescue from creation errors
      codes().create(%{
        client: client,
        resource_owner: resource_owner,
        state: state,
        scope: scope
      })
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.RefreshTokenRequest do
  import Boruta.Oauth.Authorization.Base
  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.RefreshTokenRequest
  alias Boruta.Oauth.Token

  def token(%RefreshTokenRequest{
    client_id: client_id,
    client_secret: client_secret,
    refresh_token: refresh_token,
    scope: scope
  }) do

    with {:ok, _} <- client(id: client_id, secret: client_secret),
         {:ok, %Token{
           client: client,
           resource_owner: resource_owner
         } = token} <- access_token(refresh_token: refresh_token),
         {:ok, scope} <- scope(scope: scope, against: %{token: token}) do
      # TODO rescue from creation errors
      access_tokens().create(%{
        client: client,
        resource_owner: resource_owner,
        scope: scope
      }, refresh_token: true)
    end
  end
end
