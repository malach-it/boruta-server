defmodule BorutaWeb.Admin.UserController do
  use BorutaWeb, :controller

  import BorutaWeb.Authorization, only: [
    authorize: 2
  ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.User

  plug :authorize, ["users:manage:all"]

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
    %{"sub" => sub, "username" => username} = conn.assigns[:introspected_token]
    user = %Accounts.User{id: sub, email: username}
    render(conn, "current.json", user: user)
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
