defmodule BorutaAdminWeb.PageViewTest do
  use BorutaAdminWeb.ConnCase, async: true

  import Phoenix.View

  test "renders admin page", %{conn: conn} do
    conn = get(conn, "/")

    assert render_to_string(BorutaAdminWeb.PageView, "admin.html", conn: conn) =~ "Administration panel"
  end
end
