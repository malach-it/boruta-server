defmodule BorutaWeb.UserControllerTest do
  use BorutaWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
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
      conn = get(conn, Routes.user_path(conn, :current))
      assert json_response(conn, 200)["data"] == %{
        "id" => introspected_token["sub"],
        "email" => introspected_token["username"]
      }
    end
  end
end
