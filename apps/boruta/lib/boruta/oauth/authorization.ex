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
  alias Boruta.Coherence
  alias Boruta.Coherence.User
  alias Boruta.Oauth
  alias Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest
  alias Boruta.Oauth.Schemas.Client
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%ResourceOwnerPasswordCredentialsRequest{
    client_id: client_id,
    client_secret: client_secret,
    username: username,
    password: password,
    scope: scope
  }) do

    with %Client{} = client <- Oauth.Schemas.get_by_client(id: client_id, secret: client_secret) do
      with %User{} = user <- Coherence.Schemas.get_user_by_email(username),
        true <- User.checkpw(password, user.password_hash) do
        Token.resource_owner_changeset(%Token{}, %{
          client_id: client.id,
          user_id: user.id
        })
        |> Repo.insert()
      else
        _ ->
          {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password"}}
      end
    else
      nil ->
        {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or client_secret"}}
    end
  end
end
