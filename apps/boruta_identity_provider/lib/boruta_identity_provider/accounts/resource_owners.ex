defmodule Boruta.Ecto.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  import BorutaIdentityProvider.Config, only: [repo: 0]

  alias Boruta.Accounts.HashSalt
  alias Boruta.Accounts.User
  alias Boruta.Oauth

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username, password: password) do
    with %{__struct__: _} = resource_owner <-
           repo().get_by(User, email: username),
         true <- apply(HashSalt, :checkpwd, [password, resource_owner.password_hash]) do
      resource_owner
    else
      _ -> nil
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%_{} = resource_owner) do
    resource_owner = repo().preload(resource_owner, :authorized_scopes)

    resource_owner.authorized_scopes
    |> Enum.map(fn scope -> struct(Oauth.Scope, Map.from_struct(scope)) end)
  end

  @impl Boruta.Oauth.ResourceOwners
  def persisted?(%{__meta__: %{state: :loaded}}), do: true
  def persisted?(_resource_owner), do: false
end
