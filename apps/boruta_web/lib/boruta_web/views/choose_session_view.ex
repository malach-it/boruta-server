defmodule BorutaWeb.ChooseSessionView do
  use BorutaWeb, :view

  import Plug.Conn

  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes

  def current_user_email(conn) do
    conn.assigns[:current_user].email
  end

  def delete_user_session_path(_conn) do
    IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete)
  end

  def authorize_url(conn) do
    get_session(conn, :user_return_to)
  end
end
