defmodule Boruta.Config do
  @moduledoc """
  Utilities to access Boruta configuration ad set defaults.

  Configuration can be set as following in `config.exs` (this configuration is the default)
  ```
  config :boruta, Boruta.Oauth,
    repo: Boruta.Repo,
    contexts: [
      access_tokens: Boruta.Ecto.AccessTokens,
      clients: Boruta.Ecto.Clients,
      codes: Boruta.Ecto.Codes,
      resource_owners: nil,
      scopes: Boruta.Ecto.Scopes
    ],
    expires_in: [
      authorization_code: 60,
      access_token: 3600
    ],
    token_generator: Boruta.TokenGenerator
  ```

  NOTE: Since all configurations expected `resource_owners` are macro, they are assigned at compile time
  """

  @defaults repo: Boruta.Repo,
    contexts: [
      access_tokens: Boruta.Ecto.AccessTokens,
      clients: Boruta.Ecto.Clients,
      codes: Boruta.Ecto.Codes,
      resource_owners: nil,
      scopes: Boruta.Ecto.Scopes
    ],
    expires_in: [
      authorization_code: 60,
      access_token: 3600
    ],
    token_generator: Boruta.TokenGenerator

  @spec repo() :: module()
  @doc false
  defmacro repo do
    Keyword.fetch!(oauth_config(), :repo)
  end

  @spec access_token_expires_in() :: integer()
  @doc false
  defmacro access_token_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:access_token]
  end

  @spec authorization_code_expires_in() :: integer()
  @doc false
  defmacro authorization_code_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:authorization_code]
  end

  @spec token_generator() :: module()
  @doc false
  defmacro token_generator do
    Keyword.fetch!(oauth_config(), :token_generator)
  end

  @spec access_tokens() :: module()
  @doc false
  defmacro access_tokens do
    Keyword.fetch!(oauth_config(), :contexts)[:access_tokens]
  end

  @spec clients() :: module()
  @doc false
  defmacro clients do
    Keyword.fetch!(oauth_config(), :contexts)[:clients]
  end

  @spec codes() :: module()
  @doc false
  defmacro codes do
    Keyword.fetch!(oauth_config(), :contexts)[:codes]
  end

  @spec scopes() :: module()
  @doc false
  defmacro scopes do
    Keyword.fetch!(oauth_config(), :contexts)[:scopes]
  end

  @spec resource_owners() :: module()
  @doc false
  # NOTE resource_owners is not a macro in order to get config at runtime
  def resource_owners do
    Keyword.fetch!(oauth_config(), :contexts)[:resource_owners]
  end

  @spec oauth_config() :: keyword()
  @doc false
  defp oauth_config do
      Keyword.merge(
        @defaults,
        Application.get_env(:boruta, Boruta.Oauth) || [],
        fn _, a, b ->
          if Keyword.keyword?(a) && Keyword.keyword?(b) do
            Keyword.merge(a, b)
          else
            b
          end
        end
      )
  end
end
