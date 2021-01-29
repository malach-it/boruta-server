defmodule BorutaWeb.Admin.UserController do
  use BorutaWeb, :controller

  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.Token
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  plug BorutaWeb.AuthorizationPlug, ["users:manage:all"]

  action_fallback BorutaWeb.FallbackController

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def current(conn, _) do
    %Token{resource_owner: %ResourceOwner{sub: sub}} = conn.assigns[:token]
    user = Accounts.get_user!(sub)
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => %{"authorized_scopes" => scopes}}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{} = user} <- Accounts.update_user_authorized_scopes(user, scopes) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {1, _result} <- Accounts.delete_user(id) do
      send_resp(conn, 204, "")
    end
  end
end
