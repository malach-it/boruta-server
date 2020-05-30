defmodule Boruta.Oauth.Authorization.ResourceOwner do
  @moduledoc """
  Resource owner authorization
  """

  import Boruta.Config, only: [resource_owners: 0]

  alias Boruta.Oauth.Error

  @doc """
  Authorize the resource owner corresponding to the given params.

  ## Examples
      iex> authorize(id: "id")
      {:ok, %User{...}}
  """
  @spec authorize(
    [email: String.t(), password: String.t()] |
    [resource_owner: struct()]
  ) ::
    {:error,
     %Error{
       :error => :invalid_resource_owner,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, user :: struct()}
  def authorize(username: username, password: password) do
    case resource_owners().get_by(username: username, password: password) do
      nil ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "Invalid username or password."
        }}
      resource_owner ->
      {:ok, resource_owner}
    end
  end
  def authorize(resource_owner: resource_owner) do
    case resource_owners().persisted?(resource_owner) do
      true -> {:ok, resource_owner}
      false ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "Resource owner is invalid.",
          format: :internal
        }}
    end
  end
  def authorize(_) do
    {:error, %Error{
      status: :unauthorized,
      error: :invalid_resource_owner,
      error_description: "Resource owner is invalid.",
      format: :internal
    }}
  end
end
