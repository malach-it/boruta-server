defmodule BorutaWeb.Admin.UserControllerTest do
  use BorutaWeb.ConnCase

  import Boruta.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_client_path(conn, :index))
    assert response(conn, 401)
  end

  describe "with bad scope" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token")
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn}
    end

    test "returns a 403", %{conn: conn} do
      conn = get(conn, Routes.admin_scope_path(conn, :index))
      assert response(conn, 403)
    end
  end

  describe "index" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "users:manage:all")
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn}
    end

    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "current" do
    setup %{conn: conn} do
      user = insert(:user)
      token = insert(:token, type: "access_token", scope: "users:manage:all", resource_owner_id: user.id)
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, user: user}
    end

    test "get current user", %{conn: conn, user: user} do
      conn = get(conn, Routes.admin_user_path(conn, :current))
      assert json_response(conn, 200)["data"] == %{
        "id" => user.id,
        "email" => user.email
      }
    end
  end

  describe "delete user" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "users:manage:all")
      user = insert(:user)
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, user: user}
    end

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, Routes.admin_user_path(conn, :delete, user))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.admin_user_path(conn, :show, user))
      end
    end
  end
end
