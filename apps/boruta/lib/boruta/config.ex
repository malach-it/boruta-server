defmodule Boruta.Config do
  @moduledoc """
  Utilities to access Boruta configuration ad set defaults.

  Configuration can be set as following in `config.exs`
  ```
  config :boruta, Boruta.Oauth,
    expires_in: %{
      access_token: 24 * 3600,
      authorization_code: 60
    },
    secret_key_base: System.get_env("SECRET_KEY_BASE"),
    resource_owner: %{
      schema: Boruta.Coherence.User
    }
  ```
  """

  @defaults expires_in: %{
    access_token: 3600,
    authorization_code: 60
  },
  resource_owner: %{
    schema: Boruta.Coherence.User
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
  def secret_key_base, do: Keyword.fetch!(oauth_config(), :secret_key_base)

  @doc false
  def resource_owner_schema, do: Keyword.fetch!(oauth_config(), :resource_owner)[:schema]

  defp oauth_config, do: assign_defaults(Application.get_env(:boruta, Boruta.Oauth))

  defp assign_defaults(config) do
    Keyword.merge(@defaults, config, fn _, a, b -> Map.merge(a, b) end)
  end
end
