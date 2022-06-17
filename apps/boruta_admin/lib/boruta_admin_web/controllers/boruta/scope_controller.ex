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
    "identity-providers:manage:all",
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

    with :ok <- ensure_open_for_edition(scope),
         {:ok, %Scope{} = scope} <- Admin.update_scope(scope, scope_params) do
      render(conn, "show.json", scope: scope)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = Admin.get_scope!(id)

    with :ok <- ensure_open_for_edition(scope),
         {:ok, _changes} <- BorutaAuth.Repo.transaction(delete_scope_multi(scope)) do
      send_resp(conn, :no_content, "")
    end
  end

  def ensure_open_for_edition(scope) do
    case Enum.member?(@protected_scopes, scope.name) do
      true -> {:error, :protected_resource}
      false -> :ok
    end
  end

  defp delete_scope_multi(scope) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:delete_user_scopes, fn _repo, _changes ->
      with {_deleted, nil} <- BorutaIdentity.Admin.delete_user_authorized_scopes_by_id(scope.id) do
        {:ok, nil}
      end
    end)
    |> Ecto.Multi.run(:delete_scope, fn _repo, _changes ->
      Admin.delete_scope(scope)
    end)
  end
end
