defmodule Boruta do
  @moduledoc """
  Boruta is the core of an OAuth provider giving business logic of authentication and authorization.

  It is intended to follow RFCs :
  - [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
  - [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)

  As it, it helps implement a provider for authorization code, implicit, client credentials and resource owner password credentials grants. Then it follows Introspection to check tokens.

  Note : Refresh tokens are not implemented yet

  ## Integration
  This implementation follows a pseudo hexagonal architecture to invert dependencies to Application layer.
  In order to expose endpoints of an OAuth server with Boruta, you need implement the behaviour `Boruta.Oauth.Application` with all needed callbacks for token, authorize and introspect endpoints.

  This library has some specific interfaces to interact with `Plug.Conn` requests (see: `Boruta.Oauth.Request.token_request/1` and `Boruta.Oauth.Request.introspect_request/1`)

  ## Feedback
  It is a work in progress, all feedbacks / feature requests / improvments are welcome -> [me](mailto:pascal.knoth@gmx.com)
  """
end
