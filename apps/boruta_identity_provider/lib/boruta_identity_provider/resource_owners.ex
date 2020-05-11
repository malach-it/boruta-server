defmodule BorutaIdentityProvider.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  import BorutaIdentityProvider.Config, only: [repo: 0]

  alias BorutaIdentityProvider.Accounts.HashSalt
  alias BorutaIdentityProvider.Accounts.User

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username, password: password) do
    with %User{} = resource_owner <- repo().get_by(User, email: username),
         true <- HashSalt.checkpw(password, resource_owner.password_hash) do
      resource_owner
    else
      _ -> nil
    end
  end
  def get_by(id: id) do
    repo().get(User, id)
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%User{} = user) do
    %User{authorized_scopes: scopes} = repo().preload(user, :authorized_scopes)

    # TODO improve it !
    scopes
    |> Enum.map(fn (%{scope_id: id}) -> Boruta.Ecto.Admin.get_scope!(id) end)
    |> Enum.map(fn (scope) -> struct(Boruta.Oauth.Scope, Map.from_struct(scope)) end)
  end

  @impl Boruta.Oauth.ResourceOwners
  def persisted?(%{__meta__: %{state: :loaded}}), do: true
  def persisted?(_resource_owner), do: false
end
