defmodule BorutaWeb.ChooseSessionView do
  use BorutaWeb, :view

  alias BorutaIdentityWeb.Router.Helpers, as: IdentityRoutes

  def current_user_email(conn) do
    conn.assigns[:current_user].email
  end

  def delete_user_session_path(_conn, request_param) do
    IdentityRoutes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request_param})
  end
end
