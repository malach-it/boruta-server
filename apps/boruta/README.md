# Boruta OAuth provider core
Boruta is the core of an OAuth provider giving business logic of authentication and authorization.

It is intended to follow RFCs :
- [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)
- [RFC 7009 - OAuth 2.0 Token Revocation](https://tools.ietf.org/html/rfc7009)

As it, it helps implement a provider for authorization code, implicit, client credentials and resource owner password credentials grants. Then it follows Introspection to check tokens.

## Documentation
Documentation can be found [here](https://hexdocs.pm/boruta/0.2.0/Boruta.html)

## Live example
A live example can be found [here](https://boruta.herokuapp.com/)

## Installation
1. __Schemas migration__

Boruta need a migration for its schemas and persist both tokens and clients. This can be done by running
```
mix boruta.gen.migration --with-accounts
```

2. __Configuration__

Boruta provides several configuration options, to customize them you can add configurations in `config.exs` as following
```
config :boruta, Boruta.Oauth,
  repo: Boruta.Repo,
  expires_in: %{
    access_token: 24 * 3600,
    authorization_code: 60
  },
  token_generator: Boruta.TokenGenerator,
  resource_owner: %{
    schema: Boruta.Accounts.User,
    checkpw_method: &Boruta.Accounts.HashSalt.checkpw/2
  },
  adapter: Boruta.EctoAdapter
```

## Integration
This implementation follows a pseudo hexagonal architecture to invert dependencies to Application layer.
In order to expose endpoints of an OAuth server with Boruta, you need implement the behaviour `Boruta.Oauth.Application` with all needed callbacks for `token/2`, `authorize/2` and `introspect/2` calls from `Boruta.Oauth`.

This library has specific interfaces to interact with `Plug.Conn` requests.

Here is an example of token endpoint controller:
```
defmodule MyApp.OauthController do
  @behaviour Boruta.Oauth.Application
  ...
  def token(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.Application
  def token_success(conn, %TokenResponse{} = response) do
    conn
    |> put_view(OauthView)
    |> render("token.json", response: response)
  end

  @impl Boruta.Oauth.Application
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
  ...
end
```

## Feedback
It is a work in progress, all feedbacks / feature requests / improvments are welcome
