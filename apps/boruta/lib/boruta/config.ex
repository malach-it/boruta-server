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
    resource_owner: %{
      schema: Boruta.Accounts.User,
      checkpw_method: &Boruta.Accounts.HashSalt.checkpw/2
    },
    adapter: Boruta.EctoAdapter
  ```
  """

  @defaults repo: Boruta.Repo,
    expires_in: %{
      access_token: 3600,
      authorization_code: 60
    },
    token_generator: Boruta.TokenGenerator,
    resource_owner: nil,
    adapter: Boruta.EctoAdapter

  @doc false
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
    Keyword.fetch!(oauth_config(), :expires_in)[:access_token]
  end

  @doc false
  defmacro authorization_code_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:authorization_code]
  end

  @doc false
  defmacro token_generator do
    Keyword.fetch!(oauth_config(), :token_generator)
  end

  @doc false
  defmacro adapter do
    Keyword.fetch!(oauth_config(), :adapter)
  end

  @doc false
  defmacro clients do
    adapter().clients()
  end

  @doc false
  defmacro scopes do
    adapter().scopes()
  end

  @doc false
  defmacro access_tokens do
    adapter().access_tokens()
  end

  @doc false
  defmacro codes do
    adapter().codes()
  end

  @doc false
  def resource_owners do
    Keyword.fetch!(oauth_config(), :resource_owner)[:adapter]
  end

  @doc false
  # TODO to remove
  defmacro resource_owner_schema do
    Boruta.Accounts.User
  end

  @doc false
  defmacro repo do
    Keyword.fetch!(oauth_config(), :repo)
  end
end
