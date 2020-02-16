defmodule BorutaWeb.Admin.ScopeController do
  use BorutaWeb, :controller

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Scope

  plug BorutaWeb.AuthorizationPlug, ["scopes:manage:all"]

  action_fallback BorutaWeb.FallbackController

  def index(conn, _params) do
    scopes = Admin.list_scopes()
    render(conn, "index.json", scopes: scopes)
  end

  def create(conn, %{"scope" => scope_params}) do
    with {:ok, %Scope{} = scope} <- Admin.create_scope(scope_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_scope_path(conn, :show, scope))
      |> render("show.json", scope: scope)
    end
  end

  def show(conn, %{"id" => id}) do
    scope = Admin.get_scope!(id)
    render(conn, "show.json", scope: scope)
  end

  def update(conn, %{"id" => id, "scope" => scope_params}) do
    scope = Admin.get_scope!(id)

    with {:ok, %Scope{} = scope} <- Admin.update_scope(scope, scope_params) do
      render(conn, "show.json", scope: scope)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = Admin.get_scope!(id)

    with {:ok, %Scope{}} <- Admin.delete_scope(scope) do
      send_resp(conn, :no_content, "")
    end
  end
end
