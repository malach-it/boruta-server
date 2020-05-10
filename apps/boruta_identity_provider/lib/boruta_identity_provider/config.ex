defmodule BorutaIdentityProvider.Config do
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
    adapter: Boruta.EctoAdapter
  ```
  """

  @defaults repo: BorutaIdentityProvider.Repo

  @doc false
  def accounts_config do
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
  defmacro repo do
    Keyword.fetch!(accounts_config(), :repo)
  end

  @doc false
  defmacro secret_key_base do
    Keyword.fetch!(accounts_config(), :secret_key_base)
  end
end
