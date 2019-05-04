defmodule BorutaWeb.PageController do
  use BorutaWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
