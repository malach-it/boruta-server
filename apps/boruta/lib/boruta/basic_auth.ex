defmodule Boruta.BasicAuth do
  def decode("Basic " <> encoded) do
    with {:ok, decoded} <- Base.decode64(encoded) do
      {:ok, String.split(decoded, ":")}
    end
  end
  def decode(string), do: {:error, "`#{string}` is not a valid Basic authorization header"}
end
