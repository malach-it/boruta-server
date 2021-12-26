defmodule BorutaIdentityWeb.UserRegistrationController do
  @behaviour BorutaIdentity.Accounts.RegistrationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [store_user_session: 2, after_registration_path: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.RelyingPartyError

  def new(conn, _params) do
    client_id = get_session(conn, :current_client_id)

    Accounts.initialize_registration(conn, client_id, __MODULE__)
  end

  def create(conn, %{"user" => user_params}) do
    client_id = get_session(conn, :current_client_id)

    Accounts.register(
      conn,
      client_id,
      user_params,
      &Routes.user_confirmation_url(conn, :confirm, &1),
      __MODULE__
    )
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def user_initialized(conn, changeset) do
    render(conn, "new.html", changeset: changeset)
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def registration_failure(conn, %RegistrationError{changeset: %Ecto.Changeset{} = changeset}) do
    render(conn, "new.html", changeset: changeset)
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: after_registration_path(conn))
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def user_registered(conn, _user, session_token) do
    conn
    |> store_user_session(session_token)
    |> redirect(to: after_registration_path(conn))
  end
end
