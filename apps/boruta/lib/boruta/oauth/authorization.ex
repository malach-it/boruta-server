defprotocol Boruta.Oauth.Authorization do
  @moduledoc """
  """

  @doc """
  Returns a token for given request, depending of implementation.
  """
  def token(request)
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ClientCredentialsRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%ClientCredentialsRequest{
    client_id: client_id,
    client_secret: client_secret,
    scope: scope
  }) do
    with {:ok, client} <- client(id: client_id, secret: client_secret),
      {:ok, scope} <- scope(scope: scope, client: client) do
      token = Token.machine_changeset(%Token{}, %{
        client_id: client.id,
        scope: scope
      })

      Repo.insert(token)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.PasswordRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.PasswordRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%PasswordRequest{
    client_id: client_id,
    client_secret: client_secret,
    username: username,
    password: password,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, secret: client_secret),
         {:ok, scope} <- scope(scope: scope, client: client),
         {:ok, resource_owner} <- resource_owner(email: username, password: password) do
      token = Token.resource_owner_changeset(%Token{}, %{
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        scope: scope
      })

      Repo.insert(token)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.AuthorizationCodeRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%AuthorizationCodeRequest{
    client_id: client_id,
    code: code,
    redirect_uri: redirect_uri,
  }) do
    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, code} <- code(value: code, redirect_uri: redirect_uri),
         {:ok, resource_owner} <- resource_owner(id: code.resource_owner_id) do
      token = Token.resource_owner_changeset(%Token{}, %{
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        scope: code.scope
      })

      Repo.insert(token)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.TokenRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.TokenRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%TokenRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    resource_owner: resource_owner,
    state: state,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, scope} <- scope(scope: scope, client: client),
         {:ok, resource_owner} <- resource_owner(resource_owner) do
      token = Token.resource_owner_changeset(%Token{resource_owner: resource_owner, client: client}, %{
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        state: state,
        scope: scope
      })

      Repo.insert(token)
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.CodeRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%CodeRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    resource_owner: resource_owner,
    state: state,
    scope: scope
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, scope} <- scope(scope: scope, client: client),
         {:ok, resource_owner} <- resource_owner(resource_owner) do
      token = Token.code_changeset(%Token{resource_owner: resource_owner, client: client}, %{
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: redirect_uri,
        state: state,
        scope: scope
      })

      Repo.insert(token)
    end
  end
end
