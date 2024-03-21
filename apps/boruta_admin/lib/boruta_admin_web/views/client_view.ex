defmodule BorutaAdminWeb.ClientView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.ClientView
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider

  def render("index.json", %{clients: clients}) do
    %{data: render_many(clients, ClientView, "client.json")}
  end

  def render("show.json", %{client: client}) do
    %{data: render_one(client, ClientView, "client.json")}
  end

  def render("client.json", %{client: client}) do
    identity_provider =
      IdentityProviders.get_identity_provider_by_client_id(client.id) || %IdentityProvider{}

    %{
      id: client.id,
      name: client.name,
      secret: client.secret,
      confidential: client.confidential,
      redirect_uris: client.redirect_uris,
      public_refresh_token: client.public_refresh_token,
      public_revoke: client.public_revoke,
      authorize_scope: client.authorize_scope,
      enforce_dpop: client.enforce_dpop,
      access_token_ttl: client.access_token_ttl,
      authorization_code_ttl: client.authorization_code_ttl,
      refresh_token_ttl: client.refresh_token_ttl,
      id_token_ttl: client.id_token_ttl,
      pkce: client.pkce,
      public_key: client.public_key,
      identity_provider: %{
        id: identity_provider.id,
        name: identity_provider.name
      },
      authorized_scopes:
        Enum.map(client.authorized_scopes, fn scope ->
          %{
            id: scope.id,
            name: scope.name,
            public: scope.public
          }
        end),
      supported_grant_types: client.supported_grant_types,
      id_token_signature_alg: client.id_token_signature_alg,
      userinfo_signed_response_alg: client.userinfo_signed_response_alg,
      token_endpoint_jwt_auth_alg: client.token_endpoint_jwt_auth_alg,
      token_endpoint_auth_methods: client.token_endpoint_auth_methods,
      jwt_public_key: client.jwt_public_key
    }
  end
end
