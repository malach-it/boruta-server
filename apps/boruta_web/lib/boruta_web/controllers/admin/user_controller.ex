defmodule BorutaWeb.Admin.UserController do
  use BorutaWeb, :controller

  alias Boruta.Oauth.Token
  alias BorutaIdentityProvider.Accounts
  alias BorutaIdentityProvider.Accounts.User

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
end
