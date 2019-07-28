defmodule Boruta.Config do
  @moduledoc """
  Utilities to access Boruta configuration ad set defaults.

  Configuration can be set as following in `config.exs`
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
  """

  @defaults repo: Boruta.Repo,
    expires_in: %{
      access_token: 3600,
      authorization_code: 60
    },
    token_generator: Boruta.TokenGenerator,
    resource_owner: %{
      schema: Boruta.Pow.User,
      checkpw_method: &Boruta.Pow.HashSalt.checkpw/2
    }

  @doc false
  def access_token_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:access_token]
  end

  @doc false
  def authorization_code_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:authorization_code]
  end

  @doc false
  def token_generator do
    Keyword.fetch!(oauth_config(), :token_generator)
  end

  @doc false
  def secret_key_base, do: Keyword.fetch!(oauth_config(), :secret_key_base)

  @doc false
  def resource_owner_schema, do: Keyword.fetch!(oauth_config(), :resource_owner)[:schema]

  @doc false
  def user_checkpw_method do
    Keyword.fetch!(oauth_config(), :resource_owner)[:checkpw_method]
  end

  @doc false
  def repo, do: Keyword.fetch!(oauth_config(), :repo)

  defp oauth_config, do: assign_defaults(Application.get_env(:boruta, Boruta.Oauth))

  defp assign_defaults(config) do
    Keyword.merge(@defaults, config, fn _, a, b ->
      if is_map(a) && is_map(b) do
        Map.merge(a, b)
      else
        b
      end
    end)
  end
end
