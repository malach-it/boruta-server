defmodule Boruta.Config do
  @moduledoc """
  Utilities to access Boruta configuration ad set defaults.

  Configuration can be set as following in `config.exs` (this configuration is the default)
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
      schema: Boruta.Accounts.User,
      checkpw_method: &Boruta.Accounts.HashSalt.checkpw/2
    },
    contexts: %{
      client: Boruta.Clients,
      scope: Boruta.Scopes,
      access_token: Boruta.AccessTokens,
      code: Boruta.Codes,
      resource_owner: Boruta.ResourceOwners
    }
  ```
  """

  @defaults repo: Boruta.Repo,
    expires_in: %{
      access_token: 3600,
      authorization_code: 60
    },
    token_generator: Boruta.TokenGenerator,
    resource_owner: %{
      schema: Boruta.Accounts.User,
      checkpw_method: &Boruta.Accounts.HashSalt.checkpw/2
    },
    contexts: %{
      client: Boruta.Clients,
      scope: Boruta.Scopes,
      access_token: Boruta.AccessTokens,
      code: Boruta.Codes,
      resource_owner: Boruta.ResourceOwners
    }

  def oauth_config do
      Keyword.merge(
        @defaults,
        Application.get_env(:boruta, Boruta.Oauth),
        fn _, a, b ->
          if is_map(a) && is_map(b) do
            Map.merge(a, b)
          else
            b
          end
        end
      )
  end

  @doc false
  defmacro access_token_expires_in do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :expires_in)[:access_token]
    ] do
      result
    end
  end

  @doc false
  defmacro authorization_code_expires_in do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :expires_in)[:authorization_code]
    ] do
      result
    end
  end

  @doc false
  defmacro token_generator do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :token_generator)
    ] do
      result
    end
  end

  @doc false
  defmacro secret_key_base do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :secret_key_base)
    ] do
      result
    end
  end

  @doc false
  defmacro resource_owner_schema do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :resource_owner)[:schema]
    ] do
      result
    end
  end

  @doc false
  defmacro clients do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :contexts)[:client]
    ] do
      result
    end
  end

  @doc false
  defmacro scopes do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :contexts)[:scope]
    ] do
      result
    end
  end

  @doc false
  defmacro access_tokens do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :contexts)[:access_token]
    ] do
      result
    end
  end

  @doc false
  defmacro codes do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :contexts)[:code]
    ] do
      result
    end
  end

  @doc false
  defmacro resource_owners do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :contexts)[:resource_owner]
    ] do
      result
    end
  end

  @doc false
  defmacro user_checkpw_method do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :resource_owner)[:checkpw_method]
    ] do
      result
    end
  end

  @doc false
  defmacro repo do
    quote bind_quoted: [
      result: Keyword.fetch!(oauth_config(), :repo)
    ] do
      result
    end
  end
end
