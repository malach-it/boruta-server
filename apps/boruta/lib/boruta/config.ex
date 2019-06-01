defmodule Boruta.Config do
  @moduledoc """
  Boruta config shortcuts
  """

  @defaults expires_in: %{
    access_token: 3600,
    authorization_code: 60
  }

  def access_token_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:access_token]
  end

  def authorization_code_expires_in do
    Keyword.fetch!(oauth_config(), :expires_in)[:authorization_code]
  end

  def secret_key_base, do: Keyword.fetch!(
    Application.get_env(:boruta, Boruta.Oauth),
    :secret_key_base
  )

  defp oauth_config, do: assign_defaults(Application.get_env(:boruta, Boruta.Oauth))

  defp assign_defaults(config) do
    Keyword.merge(@defaults, config, fn _, a, b -> Map.merge(a, b) end)
  end
end
