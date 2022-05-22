defmodule BorutaIdentityWeb.UserSessionController do
  @behaviour BorutaIdentity.Accounts.SessionApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      store_user_session: 2,
      get_user_session: 1,
      remove_user_session: 1,
      after_sign_in_path: 1,
      after_sign_out_path: 1,
      client_id_from_request: 1
    ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_session(conn, client_id, __MODULE__)
  end

  def create(conn, %{"user" => user_params}) do
    client_id = client_id_from_request(conn)

    authentication_params = %{
      email: user_params["email"],
      password: user_params["password"]
    }

    Accounts.create_session(conn, client_id, authentication_params, __MODULE__)
  end

  def delete(conn, _params) do
    client_id = client_id_from_request(conn)
    session_token = get_user_session(conn)

    Accounts.delete_session(conn, client_id, session_token, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def session_initialized(%Plug.Conn{} = conn, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{}
    )
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def user_authenticated(conn, _user, session_token) do
    conn
    |> store_user_session(session_token)
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def authentication_failure(%Plug.Conn{} = conn, %SessionError{
        message: message,
        template: template
      }) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message]
      }
    )
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def session_deleted(conn) do
    conn
    |> remove_user_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: after_sign_out_path(conn))
  end
end
