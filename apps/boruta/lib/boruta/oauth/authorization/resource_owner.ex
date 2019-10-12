defmodule Boruta.Oauth.Authorization.ResourceOwner do
  @moduledoc false

  import Boruta.Config, only: [user_checkpw_method: 0, resource_owner_schema: 0, repo: 0]

  alias Boruta.Oauth.Error

  @spec authorize([id: String.t()] | [email: String.t(), password: String.t()] | struct()) ::
    {:error,
     %Error{
       :error => :invalid_resource_owner,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, user :: struct()}
  def authorize(id: id) do
    # if resource_owner is a struct
    case repo().get_by(resource_owner_schema(), id: id) do
      %{__struct__: _} = resource_owner ->
        {:ok, resource_owner}
      _ ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "User not found."
        }}
    end
  end
  def authorize(email: username, password: password) do
    # if resource_owner is a struct
    with %{__struct__: _} = resource_owner <- repo().get_by(resource_owner_schema(), email: username),
         true <- apply(user_checkpw_method(), [password, resource_owner.password_hash]) do
      {:ok, resource_owner}
    else
      _ ->
        {:error, %Error{
          status: :unauthorized,
          error: :invalid_resource_owner,
          error_description: "Invalid username or password."
        }}
    end
  end
  def authorize(%{__meta__: %{state: :loaded}} = resource_owner) do # resource_owner is persisted
    {:ok, resource_owner}
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
