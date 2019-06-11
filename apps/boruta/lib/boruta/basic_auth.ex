defmodule Boruta.BasicAuth do
  @moduledoc """
  HTTP BasicAuth utilities

  Provide utilities to decode Basic authorization header as stated in [RFC 7617 - The 'Basic' HTTP Authentication Scheme](https://tools.ietf.org/html/rfc7617)
  """

  @doc """
  Decode given authorization header and returns an array containing username and password.

  ## Examples
      iex> Boruta.BasicAuth.decode("Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
      {:ok, ["username", "password"]}

      iex> Boruta.BasicAuth.decode("bad_authorization_header")
      {:error, "`bad_authorization_header` is not a valid Basic authorization header."}

  """
  @spec decode(authorization_header :: String.t()) :: {:ok, list(String.t())} | {:error, String.t()}
  def decode("Basic " <> encoded) do
    with {:ok, decoded} <- Base.decode64(encoded),
      [username, password] <- String.split(decoded, ":") do
      {:ok, [username, password]}
    else
      _ -> {:error, "Given credentials are invalid."}
    end
  end
  def decode(string) when is_binary(string), do: {:error, "`#{string}` is not a valid Basic authorization header."}
end
