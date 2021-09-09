defmodule BorutaAdminWeb.ScopeControllerTest do
  import Boruta.Factory

  use BorutaAdminWeb.ConnCase

  alias Boruta.Ecto.Scope

  @create_attrs %{
    name: "some:name",
    public: true
  }
  @update_attrs %{
    name: "some:updated:name",
    public: false
  }
  @invalid_attrs %{name: nil, public: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_scope_path(conn, :index))
    assert response(conn, 401)
  end

  describe "with bad scope" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token")

      conn =
        conn
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
      token = insert(:token, type: "access_token", scope: "scopes:manage:all")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")

      {:ok, conn: conn, scope: "scopes:manage:all"}
    end

    setup :with_authenticated_user

    test "lists all scopes", %{conn: conn} do
      conn = get(conn, Routes.admin_scope_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create scope" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "scopes:manage:all")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")

      {:ok, conn: conn, scope: "scopes:manage:all"}
    end

    setup :with_authenticated_user

    test "renders scope when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_scope_path(conn, :create), scope: @create_attrs)

      assert %{"id" => _id, "name" => "some:name", "public" => true} =
               json_response(conn, 201)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_scope_path(conn, :create), scope: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update scope" do
    setup %{conn: conn} do
      scope = insert(:scope)
      token = insert(:token, type: "access_token", scope: "scopes:manage:all")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")

      {:ok, conn: conn, existing_scope: scope, scope: "scopes:manage:all"}
    end

    setup :with_authenticated_user

    test "renders scope when data is valid", %{conn: conn, existing_scope: %Scope{id: id} = scope} do
      conn = put(conn, Routes.admin_scope_path(conn, :update, scope), scope: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, existing_scope: scope} do
      conn = put(conn, Routes.admin_scope_path(conn, :update, scope), scope: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete scope" do
    setup %{conn: conn} do
      scope = insert(:scope)
      token = insert(:token, type: "access_token", scope: "scopes:manage:all")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")

      {:ok, conn: conn, existing_scope: scope, scope: "scopes:manage:all"}
    end

    setup :with_authenticated_user

    test "deletes chosen scope", %{conn: conn, existing_scope: scope} do
      conn = delete(conn, Routes.admin_scope_path(conn, :delete, scope))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_scope_path(conn, :show, scope))
      end)
    end
  end
end
