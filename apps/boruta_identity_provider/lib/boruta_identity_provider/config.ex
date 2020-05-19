defmodule BorutaIdentityProvider.Config do
  @moduledoc """
  Utilities to access Boruta configuration ad set defaults.

  Configuration can be set as following in `config.exs` (this configuration is the default)
  ```
  config :boruta, Boruta.Oauth,
    repo: BorutaIdentityProvider.Repo,
    secret_key_base: System.get_env("SECRET_KEY_BASE")
  ```
  """

  @defaults repo: BorutaIdentityProvider.Repo

  @doc false
  def accounts_config do
      Keyword.merge(
        @defaults,
        Application.get_env(:boruta_identity_provider, Boruta.Accounts) || [],
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
  def secret_key_base do
    Keyword.fetch!(accounts_config(), :secret_key_base)
  end
end
