defmodule BorutaAdminWeb.UserController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization, only: [
    authorize: 2
  ]

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Admin

  plug :authorize, ["users:manage:all"]

  action_fallback BorutaAdminWeb.FallbackController

  def index(conn, _params) do
    users = Admin.list_users()
    render(conn, "index.json", users: users)
  end

  def show(conn, %{"id" => id}) do
    case Admin.get_user(id) do
      %User{} = user ->
        render(conn, "show.json", user: user)
      nil ->
        {:error, :not_found}
    end
  end

  def update(conn, %{"id" => id, "user" => %{"authorized_scopes" => scopes}}) do
    with %User{} = user <- Admin.get_user(id),
      {:ok, %User{} = user} <- Admin.update_user_authorized_scopes(user, scopes) do
      render(conn, "show.json", user: user)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, _user} <- Admin.delete_user(id) do
      send_resp(conn, 204, "")
    end
  end

  def current(conn, _) do
    %{"sub" => sub, "username" => username} = conn.assigns[:introspected_token]
    user = %User{id: sub, username: username}
    render(conn, "current.json", user: user)
  end
end
