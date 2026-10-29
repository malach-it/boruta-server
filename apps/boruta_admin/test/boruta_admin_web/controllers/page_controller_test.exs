defmodule BorutaAdminWeb.PageControllerTest do
  use BorutaAdminWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "app"
  end
end
