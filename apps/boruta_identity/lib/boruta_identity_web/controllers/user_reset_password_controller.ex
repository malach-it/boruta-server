defmodule BorutaIdentityWeb.UserResetPasswordController do
  @behaviour BorutaIdentity.Accounts.ResetPasswordApplication

  use BorutaIdentityWeb, :controller

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.ResetPasswordError

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    client_id = get_session(conn, :current_client_id)

    user_params = %{
      email: email
    }

    Accounts.send_reset_password_instructions(
      conn,
      client_id,
      user_params,
      &Routes.user_reset_password_url(conn, :edit, &1),
      __MODULE__
    )
  end

  def edit(conn, params) do
    client_id = get_session(conn, :current_client_id)

    Accounts.initialize_password_reset(conn, client_id, params["token"], __MODULE__)
  end

  def update(conn, params) do
    client_id = get_session(conn, :current_client_id)

    user_params = Map.get(params, "user", %{})

    reset_password_params = %{
      reset_password_token: params["token"],
      password: user_params["password"],
      password_confirmation: user_params["password_confirmation"]
    }

    Accounts.reset_password(conn, client_id, reset_password_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def reset_password_instructions_delivered(conn) do
    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_initialized(conn, token, changeset) do
    render(conn, "edit.html", changeset: changeset, token: token)
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reseted(conn, _user) do
    # Do not log in the user after reset password to avoid a
    # leaked token giving the user access to the account.
    conn
    |> put_flash(:info, "Password reset successfully.")
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_failure(conn, %ResetPasswordError{
        changeset: %Ecto.Changeset{} = changeset,
        message: message,
        token: token
      }) do
    conn
    |> put_flash(:error, message)
    |> render("edit.html", changeset: changeset, token: token)
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_failure(conn, %ResetPasswordError{
        message: message
      }) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new))
  end
end
