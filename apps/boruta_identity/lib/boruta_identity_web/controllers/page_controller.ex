defmodule BorutaIdentityWeb.PageController do
  use BorutaIdentityWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
