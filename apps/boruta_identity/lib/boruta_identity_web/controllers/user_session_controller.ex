defmodule BorutaIdentityWeb.UserSessionController do
  @behaviour BorutaIdentity.Accounts.SessionApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [store_session: 2, after_sign_in_path: 1, log_out_user: 1]

  alias BorutaIdentity.Accounts

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    client_id = get_session(conn, :current_client_id)

    authentication_params = %{
      email: user_params["email"],
      password: user_params["password"]
    }

    Accounts.create_session(conn, client_id, authentication_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def user_authenticated(conn, _user, session_token) do
    conn
    |> store_session(session_token)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def authentication_failure(conn, _authentication_error) do
    render(conn, "new.html", error_message: "Invalid email or password")
  end

  def delete(conn, _params) do
    conn
    |> log_out_user()
    |> put_flash(:info, "Logged out successfully.")
  end
end
