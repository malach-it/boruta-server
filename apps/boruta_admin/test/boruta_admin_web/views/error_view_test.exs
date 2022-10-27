defmodule BorutaAdminWeb.ErrorViewTest do
  use BorutaAdminWeb.ConnCase, async: true

  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(BorutaAdminWeb.ErrorView, "404.html", []) =~ "Page not found"
  end

  test "renders 500.html" do
    assert render_to_string(BorutaAdminWeb.ErrorView, "500.html", []) =~ "Internal server error"
  end
end
