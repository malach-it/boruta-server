defmodule BorutaIdentityProvider.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  import BorutaIdentityProvider.Config, only: [repo: 0]

  alias BorutaIdentityProvider.Accounts
  alias BorutaIdentityProvider.Accounts.User

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username, password: password) do
    with %User{} = resource_owner <- Accounts.get_user_by(email: username),
         :ok <- Accounts.check_password(resource_owner, password) do
      resource_owner
    else
      _ -> nil
    end
  end
  def get_by(id: id) do
    Accounts.get_user_by(id: id)
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%User{} = user) do
    %User{authorized_scopes: scopes} = repo().preload(user, :authorized_scopes)

    Enum.map(scopes, fn (%{scope_id: id}) -> id end)
    |> Boruta.Ecto.Admin.get_scopes_by_ids()
    |> Enum.map(fn (scope) -> struct(Boruta.Oauth.Scope, Map.from_struct(scope)) end)
  end

  @impl Boruta.Oauth.ResourceOwners
  def persisted?(%{__meta__: %{state: :loaded}}), do: true
  def persisted?(_resource_owner), do: false
end
