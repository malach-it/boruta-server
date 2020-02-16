defprotocol Boruta.Ecto.OauthMapper do
  @fallback_to_any true
  def to_oauth_schema(schema)
end

defimpl Boruta.Ecto.OauthMapper, for: Any do
  def to_oauth_schema(schema), do: schema
end

defimpl Boruta.Ecto.OauthMapper, for: Boruta.Ecto.Token do
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth
  alias Boruta.Ecto
  alias Boruta.Ecto.OauthMapper

  def to_oauth_schema(%Ecto.Token{} = token) do
    token = repo().preload(token, [:client, resource_owner: :authorized_scopes])

    struct(
      Oauth.Token,
      Map.merge(
        Map.from_struct(token),
        %{client: OauthMapper.to_oauth_schema(token.client)}
      )
    )
  end
end

defimpl Boruta.Ecto.OauthMapper, for: Boruta.Ecto.Client do
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth
  alias Boruta.Ecto

  def to_oauth_schema(%Ecto.Client{} = client) do
    client = repo().preload(client, :authorized_scopes)

    struct(
      Oauth.Client,
      Map.merge(
        Map.from_struct(client),
        %{
          authorized_scopes:
            Enum.map(client.authorized_scopes, fn scope ->
              # TODO to_oauth_schema(scope)
              struct(Oauth.Scope, Map.from_struct(scope))
            end)
        }
      )
    )
  end
end

defimpl Boruta.Ecto.OauthMapper, for: Boruta.Ecto.Scope do
  alias Boruta.Ecto
  alias Boruta.Oauth

  def to_oauth_schema(%Ecto.Scope{} = scope) do
    struct(Oauth.Scope, Map.from_struct(scope))
  end
end
