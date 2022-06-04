defmodule BorutaAdminWeb.ScopeController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Scope

  @protected_scopes [
    "users:manage:all",
    "clients:manage:all",
    "relying-parties:manage:all",
    "scopes:manage:all",
    "upstreams:manage:all"
  ]

  plug(:authorize, ["scopes:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

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

    with :ok <- ensure_deletion_allowed(scope),
         {:ok, %Scope{}} <- Admin.delete_scope(scope) do
      send_resp(conn, :no_content, "")
    end
  end

  def ensure_deletion_allowed(scope) do
    case Enum.member?(@protected_scopes, scope.name) do
      true -> {:error, :forbidden}
      false -> :ok
    end
  end
end
