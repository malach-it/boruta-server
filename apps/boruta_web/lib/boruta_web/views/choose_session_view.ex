defmodule BorutaWeb.ChooseSessionView do
  use BorutaWeb, :view

  import Plug.Conn

  def current_user_email(conn) do
    conn.assigns[:current_user].email
  end

  def authorize_url(conn) do
    with params <- get_session(conn, :oauth_request) do
      Routes.oauth_path(conn, :authorize, %{
        response_type: params["response_type"],
        client_id: params["client_id"],
        redirect_uri: params["redirect_uri"],
        scope: params["scope"],
        state: params["state"]
      })
    end
  end
end
