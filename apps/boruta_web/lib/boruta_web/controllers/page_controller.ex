defmodule BorutaWeb.PageController do
  use BorutaWeb, :controller

  def index(conn, _params) do
    conn
    |> put_layout(false)
    |> render("index.html")
  end

  def admin(conn, _params) do
    conn
    |> put_layout(false)
    |> render("admin.html")
  end
end
