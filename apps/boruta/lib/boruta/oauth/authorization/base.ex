defmodule Boruta.Oauth.Authorization.Base do
  @moduledoc """
  Base artifacts authorization
  """

  alias Boruta.Oauth.Authorization

  @doc """
  Authorize the client corresponding to the given params.

  ## Examples
      iex> client(id: "id", secret: "secret")
      {:ok, %Boruta.Oauth.Client{...}}
  """
  defdelegate client(params), to: Authorization.Client, as: :authorize

  @doc """
  Authorize the resource owner corresponding to the given params.

  ## Examples
      iex> resource_owner(id: "id")
      {:ok, %User{...}}
  """
  defdelegate resource_owner(params), to: Authorization.ResourceOwner, as: :authorize

  @doc """
  Authorize the code corresponding to the given params.

  ## Examples
      iex> code(value: "value", redirect_uri: "redirect_uri")
      {:ok, %Boruta.Oauth.Token{...}}
  """
  defdelegate code(params), to: Authorization.Code, as: :authorize

  @doc """
  Authorize the access token corresponding to the given params.

  ## Examples
      iex> access_token(%{value: "value"})
      {:ok, %Boruta.Oauth.Token{...}}
  """
  defdelegate access_token(params), to: Authorization.AccessToken, as: :authorize

  @doc """
  Authorize the given scope according to the given client.

  ## Examples
      iex> scope(scope: "scope", client: %Boruta.Oauth.Client{...})
      {:ok, "scope"}
  """
  defdelegate scope(params), to: Authorization.Scope, as: :authorize
end
