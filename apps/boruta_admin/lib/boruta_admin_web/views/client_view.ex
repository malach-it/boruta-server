defmodule BorutaAdminWeb.ClientView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.ClientView
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  def render("index.json", %{clients: clients}) do
    %{data: render_many(clients, ClientView, "client.json")}
  end

  def render("show.json", %{client: client}) do
    %{data: render_one(client, ClientView, "client.json")}
  end

  def render("client.json", %{client: client}) do
    relying_party = RelyingParties.get_client_relying_party(client.id) || %RelyingParty{}

    %{
      id: client.id,
      name: client.name,
      secret: client.secret,
      redirect_uris: client.redirect_uris,
      public_refresh_token: client.public_refresh_token,
      public_revoke: client.public_revoke,
      authorize_scope: client.authorize_scope,
      access_token_ttl: client.access_token_ttl,
      authorization_code_ttl: client.authorization_code_ttl,
      refresh_token_ttl: client.refresh_token_ttl,
      id_token_ttl: client.id_token_ttl,
      pkce: client.pkce,
      public_key: client.public_key,
      relying_party: %{
        id: relying_party.id,
        name: relying_party.name,
        type: relying_party.type
      },
      authorized_scopes: Enum.map(client.authorized_scopes, fn (scope) ->
        %{
          id: scope.id,
          name: scope.name,
          public: scope.public
        }
      end),
      supported_grant_types: client.supported_grant_types
    }
  end
end
