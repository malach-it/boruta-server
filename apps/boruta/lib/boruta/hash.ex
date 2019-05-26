defmodule Boruta.Hash do
  # maybe not the better secure way to hash password but way faster than Bcrypt
  def hashpwsalt(password) do
    hash(password)
  end

  def checkpw(input, password_hash) do
    hash(input) == password_hash
  end

  defp hash(string) when is_binary(string) do
    :crypto.hash(:sha512, string) |> Base.encode16
  end
end
