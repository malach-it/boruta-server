defmodule Boruta.Coherence.HashSalt do
  @moduledoc false

  import Boruta.Config, only: [secret_key_base: 0]

  def hashpwsalt(password) do
    hash(password)
  end

  def checkpw(input, password_hash) do
    hash(input) == password_hash
  end

  defp hash(string) when is_binary(string) do
    :crypto.hmac(:sha512, salt(), string) |> Base.encode16
  end

  defp salt, do: secret_key_base()
end
