defmodule BorutaAdminWeb.BackendControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Backends
  alias BorutaIdentity.Backends.Backend

  @create_attrs %{
    name: "some name",
    type: "internal"
  }
  @update_attrs %{
    name: "some updated name"
  }
  @update_template_attrs %{
    content: "some updated content"
  }
  @invalid_attrs %{content: nil, type: "other"}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_backend_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_backend_path(conn, :index))
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
    @tag authorized: ["identity-providers:manage:all"]
    test "lists all backends", %{conn: conn} do
      conn = get(conn, Routes.admin_backend_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end
end
