defmodule BorutaAdminWeb.RoleControllerTest do
  import BorutaIdentity.Factory

  use BorutaAdminWeb.ConnCase

  alias BorutaIdentity.Accounts.Role

  @create_attrs %{
    name: "some name",
  }
  @update_attrs %{
    name: "some updated name"
  }
  @invalid_attrs %{name: nil}
  @protected_roles []

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # TODO test sub restriction
  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_role_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_role_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_role_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_role_path(conn, :delete, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "with bad role" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_role_path(conn, :index))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_role_path(conn, :create))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_role_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_role_path(conn, :delete, "id"))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["roles:manage:all"]
    test "lists all roles", %{conn: conn} do
      conn = get(conn, Routes.admin_role_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create role" do
    @tag authorized: ["roles:manage:all"]
    test "renders role when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_role_path(conn, :create), role: @create_attrs)

      assert %{"id" => _id, "name" => "some name"} =
               json_response(conn, 201)["data"]
    end

    @tag authorized: ["roles:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_role_path(conn, :create), role: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update role" do
    setup %{conn: conn} do
      role = insert(:role)

      {:ok, conn: conn, existing_role: role}
    end

    @tag authorized: ["roles:manage:all"]
    test "renders role when data is valid", %{conn: conn, existing_role: %Role{id: id} = role} do
      conn = put(conn, Routes.admin_role_path(conn, :update, role), role: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag authorized: ["roles:manage:all"]
    test "cannot update protected roles", %{conn: conn} do
      Enum.map(@protected_roles, fn name ->
        conn = put(conn, Routes.admin_role_path(conn, :update, insert(:role, name: name)), role: @update_attrs)

        assert response(conn, 403)
      end)
    end

    @tag authorized: ["roles:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, existing_role: role} do
      conn = put(conn, Routes.admin_role_path(conn, :update, role), role: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete role" do
    setup %{conn: conn} do
      role = insert(:role)

      {:ok, conn: conn, existing_role: role}
    end

    @tag authorized: ["roles:manage:all"]
    test "cannot delete protected roles", %{conn: conn} do
      Enum.map(@protected_roles, fn name ->
        conn = delete(conn, Routes.admin_role_path(conn, :delete, insert(:role, name: name)))

        assert response(conn, 403)
      end)
    end

    @tag authorized: ["roles:manage:all"]
    test "deletes chosen role", %{conn: conn, existing_role: role} do
      conn = delete(conn, Routes.admin_role_path(conn, :delete, role))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_role_path(conn, :show, role))
      end)
    end
  end
end
