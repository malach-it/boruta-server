defmodule BorutaWeb.ChooseSessionController do
  use BorutaWeb, :controller

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes

  def new(%Plug.Conn{assigns: %{current_user: %User{}}} = conn, _params) do
    conn
    |> put_session(:session_chosen, true)
    |> put_view(BorutaWeb.ChooseSessionView)
    |> render("new.html")
  end
  def new(%Plug.Conn{} = conn, _) do
    conn
    |> redirect(to: IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :new))
  end
end
