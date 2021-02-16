defmodule BorutaWeb.Admin.UserControllerTest do
  use BorutaWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.User

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_client_path(conn, :index))
    assert response(conn, 401)
  end

  describe "with bad scope" do
    setup %{conn: conn} do
      token = Boruta.Factory.insert(:token, type: "access_token")
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, scope: "bad:scope"}
    end
    setup :with_authenticated_user

    test "returns a 403", %{conn: conn} do
      conn = get(conn, Routes.admin_scope_path(conn, :index))
      assert response(conn, 403)
    end
  end

  describe "index" do
    setup %{conn: conn} do
      token = Boruta.Factory.insert(:token, type: "access_token", scope: "users:manage:all")
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, scope: "users:manage:all"}
    end
    setup :with_authenticated_user

    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "current" do
    setup %{conn: conn} do
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer token_authorized_by_with_authenticated_user")
      {:ok, conn: conn, scope: "users:manage:all"}
    end
    setup :with_authenticated_user

    test "get current user", %{conn: conn, introspected_token: introspected_token} do
      conn = get(conn, Routes.admin_user_path(conn, :current))
      assert json_response(conn, 200)["data"] == %{
        "id" => introspected_token["sub"],
        "email" => introspected_token["username"]
      }
    end
  end

  describe "update resource_owner" do
    setup %{conn: conn} do
      token = Boruta.Factory.insert(:token, type: "access_token", scope: "users:manage:all")
      resource_owner = user_fixture()
      scope = Boruta.Factory.insert(:scope)
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, resource_owner: resource_owner, existing_scope: scope, scope: "users:manage:all"}
    end
    setup :with_authenticated_user

    test "renders resource_owner when data is valid", %{
      conn: conn,
      resource_owner: %User{id: id} = resource_owner,
      existing_scope: scope
    } do
      conn = put(conn, Routes.admin_user_path(conn, :update, resource_owner), user: %{
        "authorized_scopes" => [%{"name" => scope.name}]
      })
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end
  end

  @tag :skip
  describe "delete" do
  end
end
