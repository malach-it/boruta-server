defmodule BorutaIdentityWeb.UserConfirmationController do
  @behaviour BorutaIdentity.Accounts.ConfirmationApplication

  use BorutaIdentityWeb, :controller

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.ConfirmationError
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties.Template

  def new(conn, _params) do
    client_id = get_session(conn, :current_client_id)

    Accounts.initialize_confirmation_instructions(conn, client_id, __MODULE__)
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    client_id = get_session(conn, :current_client_id)

    confirmation_params = %{
      email: email
    }

    Accounts.send_confirmation_instructions(
      conn,
      client_id,
      confirmation_params,
      &Routes.user_confirmation_url(conn, :confirm, &1),
      __MODULE__
    )
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def confirm(conn, %{"token" => token}) do
    client_id = get_session(conn, :current_client_id)
    current_user = conn.assigns[:current_user]

    Accounts.confirm_user(conn, client_id, current_user, token, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def user_confirmed(conn, _user) do
    conn
    |> put_flash(:info, "Account confirmed successfully.")
    |> redirect(to: "/")
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def user_confirmation_failure(conn, %ConfirmationError{message: message}) do
    case conn.assigns[:current_user] do
      %User{} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/")

      _ ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.user_session_path(conn, :new))
    end
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def confirmation_instructions_delivered(conn) do
    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: "/")
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def confirmation_instructions_initialized(conn, relying_party, template) do
    render(conn, "new.html", template: compile_template(template, %{relying_party: relying_party}))
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  defp compile_template(%Template{content: content}, opts) do
    context = %{
      create_user_confirmation_path:
        Routes.user_confirmation_path(BorutaIdentityWeb.Endpoint, :create),
      new_user_registration_path: Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new),
      new_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :new),
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      registrable?: Map.fetch!(opts, :relying_party).registrable
    }

    Mustachex.render(content, context)
  end
end
