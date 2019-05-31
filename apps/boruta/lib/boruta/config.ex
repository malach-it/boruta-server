defmodule Boruta.Config do
  @defaults %{
    expires_in: %{
      access_token: 3600,
      authorization_code: 60
    }
  }

  def access_token_expires_in() do
    oauth_config()[:expires_in][:access_token]
  end

  def authorization_code_expires_in() do
    oauth_config()[:expires_in][:authorization_code]
  end

  defp oauth_config(), do: assign_defaults(Application.get_env(:boruta, :oauth))

  defp assign_defaults(config) do
    Map.merge(@defaults, config, fn _, a, b -> Map.merge(a, b) end)
  end
end
