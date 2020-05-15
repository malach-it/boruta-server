defmodule BorutaWeb.Admin.UserController do
  use BorutaWeb, :controller

  alias BorutaIdentityProvider.Accounts
  alias BorutaIdentityProvider.Accounts.User
  alias Boruta.Oauth.Token

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
    %Token{resource_owner: resource_owner} = conn.assigns[:token]
    render(conn, "show.json", user: resource_owner)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Admin.get_user!(id)

    with {:ok, %User{}} <- Admin.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end
end
