defprotocol Boruta.Oauth.Authorization do
  def token(request)
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ClientCredentialsRequest do
  alias Authable.Model.Token
  alias Boruta.Oauth.ClientCredentialsRequest

  def token(%ClientCredentialsRequest{client_id: client_id, client_secret: client_secret, scope: scope}) do
    with %Token{} = token <- Authable.OAuth2.authorize(%{
      "grant_type" => "client_credentials",
      "client_id" => client_id,
      "client_secret" => client_secret,
      "scope" => scope
    }) do
      {:ok, token}
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest do
  alias Authable.Model.Token
  alias Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest

  def token(%ResourceOwnerPasswordCredentialsRequest{
    client_id: client_id,
    client_secret: client_secret,
    username: username,
    password: password,
    scope: scope
  }) do
    with %Token{} = token <- Authable.OAuth2.authorize(%{
      "grant_type" => "client_credentials",
      "client_id" => client_id,
      "client_secret" => client_secret,
      "email" => username,
      "password" => password,
      "scope" => scope
    }) do
      {:ok, token}
    end
  end
end
