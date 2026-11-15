defmodule BorutaAuth.GatewaySession do
  @moduledoc false
  @ttl 3600
  @salt "boruta gateway browser session v1"

  def encode(session) do
    Plug.Crypto.encrypt(secret_key_base!(), @salt, session, max_age: @ttl)
  end

  def decode(nil), do: nil

  def decode(value) when is_binary(value) do
    secret = Application.get_env(:boruta_gateway, :session_secret_key_base)

    if is_binary(secret) && byte_size(secret) >= 64 do
      case Plug.Crypto.decrypt(secret, @salt, value, max_age: @ttl) do
        {:ok, session} when is_map(session) -> session
        _ -> nil
      end
    end
  end

  def decode(_value), do: nil

  defp secret_key_base! do
    secret = Application.get_env(:boruta_gateway, :session_secret_key_base)

    if is_binary(secret) && byte_size(secret) >= 64 do
      secret
    else
      raise "gateway cookie sessions require SECRET_KEY_BASE of at least 64 bytes"
    end
  end
end
