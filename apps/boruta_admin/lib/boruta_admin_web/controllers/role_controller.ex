defmodule BorutaAdminWeb.RoleController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Admin

  plug(:authorize, ["roles:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, _params) do
    roles = Admin.list_roles()
    render(conn, "index.json", roles: roles)
  end

  def create(conn, %{"role" => role_params}) do
    with {:ok, %Role{} = role} <- Admin.create_role(role_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_role_path(conn, :show, role))
      |> render("show.json", role: role)
    end
  end

  def show(conn, %{"id" => id}) do
    role = Admin.get_role!(id)
    render(conn, "show.json", role: role)
  end

  def update(conn, %{"id" => id, "role" => role_params}) do
    role = Admin.get_role!(id)

    with :ok <- ensure_open_for_edition(role),
         {:ok, %Role{} = role} <- Admin.update_role(role, role_params) do
      render(conn, "show.json", role: role)
    end
  end

  def delete(conn, %{"id" => id}) do
    role = Admin.get_role!(id)

    with :ok <- ensure_open_for_edition(role),
         {:ok, _changes} <- Admin.delete_role(role) do
      send_resp(conn, :no_content, "")
    end
  end

  def ensure_open_for_edition(_role) do
    :ok
  end
end
