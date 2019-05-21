defprotocol Boruta.Oauth.Authorization do
  def authorize(request)
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ClientCredentialsRequest do
  alias Authable.Model.Token
  alias Boruta.Oauth.ClientCredentialsRequest

  def authorize(%ClientCredentialsRequest{client_id: client_id, client_secret: client_secret, scope: scope}) do
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
