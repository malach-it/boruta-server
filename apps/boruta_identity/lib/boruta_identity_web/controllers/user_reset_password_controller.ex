defmodule BorutaIdentityWeb.UserResetPasswordController do
  @behaviour BorutaIdentity.Accounts.ResetPasswordApplication

  use BorutaIdentityWeb, :controller

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.ResetPasswordError
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.ErrorHelpers

  def new(conn, _params) do
    client_id = get_session(conn, :current_client_id)

    Accounts.initialize_password_instructions(conn, client_id, __MODULE__)
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
  def password_instructions_initialized(conn, relying_party, template) do
    render(conn, "new.html", template: compile_template(template, %{relying_party: relying_party}))
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
  def password_reset_initialized(conn, token, relying_party, template) do
    render(conn, "edit.html",
      template: compile_template(template, %{relying_party: relying_party, token: token})
    )
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
        relying_party: relying_party,
        template: template,
        changeset: %Ecto.Changeset{} = changeset,
        token: token
      }) do
    conn
    |> render("edit.html",
      template:
        compile_template(template, %{
          valid?: false,
          relying_party: relying_party,
          changeset: changeset,
          token: token
        })
    )
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_failure(conn, %ResetPasswordError{
        message: message
      }) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  defp compile_template(%Template{content: content}, opts) do
    errors =
      case Map.fetch(opts, :changeset) do
        {:ok, changeset} ->
          changeset
          |> ErrorHelpers.error_messages()
          |> Enum.map(fn message -> %{message: message} end)

        :error ->
          []
      end

    context = %{
      create_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :create),
      update_user_reset_password_path:
        Routes.user_reset_password_path(
          BorutaIdentityWeb.Endpoint,
          :update,
          Map.get(opts, :token, "")
        ),
      new_user_session_path: Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new),
      new_user_registration_path: Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new),
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      valid?: Map.get(opts, :valid?, true),
      errors: errors,
      registrable?: Map.fetch!(opts, :relying_party).registrable
    }

    Mustachex.render(content, context)
  end
end
