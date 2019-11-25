defmodule BorutaWeb.ChooseSessionController do
  use BorutaWeb, :controller

  alias Boruta.Accounts.User

  def new(%Plug.Conn{assigns: %{current_user: %User{}}} = conn, _params) do
    conn
    |> put_session(:session_chosen, true)
    |> put_view(BorutaWeb.ChooseSessionView)
    |> render("new.html")
  end
  def new(%Plug.Conn{} = conn, _) do
    conn
    |> redirect(to: Routes.pow_session_path(conn, :new))
  end
end
