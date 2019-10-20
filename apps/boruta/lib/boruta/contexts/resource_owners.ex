defmodule Boruta.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  import Boruta.Config, only: [user_checkpw_method: 0, resource_owner_schema: 0, repo: 0]

  alias Boruta.Oauth

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username, password: password) do
    with %{__struct__: _} = resource_owner <- repo().get_by(resource_owner_schema(), email: username),
         true <- apply(user_checkpw_method(), [password, resource_owner.password_hash]) do
      resource_owner
    else
      _ -> nil
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%_{} = resource_owner) do
    resource_owner = repo().preload(resource_owner, :authorized_scopes)
    resource_owner.authorized_scopes
    |> Enum.map(fn (scope) -> struct(Oauth.Scope, Map.from_struct(scope)) end)
  end

  @impl Boruta.Oauth.ResourceOwners
  def persisted?(%{__meta__: %{state: :loaded}}), do: true
  def persisted?(_resource_owner), do: false
end
