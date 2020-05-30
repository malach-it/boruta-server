defmodule Boruta do
  @moduledoc """
  Boruta is the core of an OAuth provider giving business logic of authentication and authorization.

  It is intended to follow RFCs :
  - [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
  - [RFC 7662 - OAuth 2.0 Token Introspection](https://tools.ietf.org/html/rfc7662)
  - [RFC 7009 - OAuth 2.0 Token Revocation](https://tools.ietf.org/html/rfc7009)

  As it, it helps implement a provider for authorization code, implicit, client credentials and resource owner password credentials grants. Then it follows Introspection to check tokens.

  Note : Refresh tokens are not implemented yet

  ## Installation
  1. __Schemas migration__

  If you plan to use Boruta builtin clients and tokens contexts, you'll need a migration for its `Ecto` schemas. This can be done by running :
  ```
  mix boruta.gen.migration
  ```

  2. Implement ResourceOwners context

  In order to have user flows working, You need to implement `Boruta.Oauth.ResourceOwners`.

  Here is an example implementation :
  ```
  defmodule MyApp.ResourceOwners do
    @behaviour Boruta.Oauth.ResourceOwners

    alias MyApp.Accounts.User
    alias MyApp.Repo

    @impl Boruta.Oauth.ResourceOwners
    def get_by(username: username, password: password) do
      with %User{} = user <- Repo.get_by(User, email: username),
        :ok <- User.check_password(user, password) do
          user
      else
        _ -> nil
      end
    end
    def get_by(id: id) do
      Repo.get(id)
    end

    @impl Boruta.Oauth.ResourceOwners
    def authorized_scopes(%User{}), do: []

    @impl Boruta.Oauth.ResourceOwners
    def persisted?(%{__meta__: %{state: :loaded}}), do: true
    def persisted?(_resource_owner), do: false
  end
  ```

  3. __Configuration__

  Boruta provides several configuration options, to customize them you can add configurations in `config.exs` as following
  ```
  config :boruta, Boruta.Oauth,
    repo: Boruta.Repo,
    contexts: [
      access_tokens: Boruta.Ecto.AccessTokens,
      clients: Boruta.Ecto.Clients,
      codes: Boruta.Ecto.Codes,
      resource_owners: MyApp.ResourceOwners,
      scopes: Boruta.Ecto.Scopes
    ],
    expires_in: [
      authorization_code: 60,
      access_token: 3600
    ],
    token_generator: Boruta.TokenGenerator
  ```

  ## Integration
  This implementation follows a pseudo hexagonal architecture to invert dependencies to Application layer.
  In order to expose endpoints of an OAuth server with Boruta, you need implement the behaviour `Boruta.Oauth.Application` with all needed callbacks for `token/2`, `authorize/2` and `introspect/2` calls from `Boruta.Oauth`.

  This library has specific interfaces to interact with `Plug.Conn` requests.

  ## Feedback
  It is a work in progress, all feedbacks / feature requests / improvments are welcome -> [me](mailto:pascal.knoth@gmx.com)
  """
end
