defmodule BorutaFederationWeb.PageControllerTest do
  use BorutaFederationWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "ok"
  end
end
