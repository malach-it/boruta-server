defmodule BorutaAdminWeb.PageController do
  use BorutaAdminWeb, :controller

  def index(conn, _params) do
    conn
    |> put_layout(false)
    |> render("admin.html")
  end
end
