# Boruta
Boruta is the core of an OAuth provider giving business logic of authentication and authorization.

It is intended to follow RFCs :
- [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)

As it, it helps implement a provider for authorization code, implicit, client credentials and resource owner password credentials grants. Then it follows Introspection to check tokens.

Note : Refresh tokens are not implemented yet

## Live example
A live example can be found [here](https://boruta.herokuapp.com/)

## Installation
1. __Schemas migration__

Boruta need a migration for its schemas and persist both tokens and clients. This can be done by running
```
mix boruta.gen.migration
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
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  resource_owner: %{
    schema: Boruta.Coherence.User
  }
```

## Integration
This implementation follows a pseudo hexagonal architecture to invert dependencies to Application layer.
In order to expose endpoints of an OAuth server with Boruta, you need implement the behaviour `Boruta.Oauth.Application` with all needed callbacks for `token/2`, `authorize/2` and `introspect/2` calls from `Boruta.Oauth`.

This library has specific interfaces to interact with `Plug.Conn` requests.

## Feedback
It is a work in progress, all feedbacks / feature requests / improvments are welcome -> [me](mailto:pascal.knoth@gmx.com)
