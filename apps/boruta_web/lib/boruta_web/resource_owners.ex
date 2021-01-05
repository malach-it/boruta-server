defmodule BorutaWeb.ResourceOwners do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username) do
    case Accounts.get_user_by(email: username) do
      %User{id: id, email: email} ->
        {:ok, %ResourceOwner{sub: id, username: email}}
      _ -> {:error, "User not found."}
    end
  end
  def get_by(sub: sub) do
    case Accounts.get_user_by(id: sub) do
      %User{id: id, email: email} ->
        {:ok, %ResourceOwner{sub: id, username: email}}
      _ -> {:error, "User not found."}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def check_password(%ResourceOwner{sub: sub}, password) do
    user = Accounts.get_user_by(id: sub)
    Accounts.check_password(user, password)
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{sub: sub}) do
    scopes = Accounts.get_user_scopes(sub)

    Enum.map(scopes, fn (%{id: id, name: name}) -> %Scope{id: id, name: name} end)
  end
end
