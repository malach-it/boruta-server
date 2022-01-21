defmodule BorutaIdentityWeb.UserRegistrationController do
  @behaviour BorutaIdentity.Accounts.RegistrationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [store_user_session: 2, after_registration_path: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.ErrorHelpers

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
  def registration_initialized(conn, changeset, template) do
    render(conn, "new.html", changeset: changeset, template: compile_template(template))
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def registration_failure(conn, %RegistrationError{
        changeset: %Ecto.Changeset{} = changeset,
        template: template
      }) do
    render(conn, "new.html",
      changeset: changeset,
      template: compile_template(template, %{changeset: changeset, valid?: false})
    )
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

  defp compile_template(%Template{content: content}, opts \\ %{}) do
    errors = case Map.fetch(opts, :changeset)  do
      {:ok, changeset} -> changeset |> ErrorHelpers.error_messages() |> Enum.map(fn message -> %{message: message} end)
      :error -> []
    end

    context = %{
      create_user_registration_url:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :create),
      new_user_session_url: Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new),
      new_user_reset_password_url:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :new),
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      # TODO improve error format
      errors: errors,
      valid?: Map.get(opts, :valid?, true)
    }

    Mustachex.render(content, context)
  end
end
