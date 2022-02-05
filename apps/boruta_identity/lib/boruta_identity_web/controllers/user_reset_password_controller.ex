defmodule BorutaIdentityWeb.UserResetPasswordController do
  @behaviour BorutaIdentity.Accounts.ResetPasswordApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [client_id_from_request: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.Accounts.ResetPasswordError
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.ErrorHelpers

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_password_instructions(conn, client_id, __MODULE__)
  end

  def create(%Plug.Conn{query_params: query_params} = conn, %{"user" => %{"email" => email}}) do
    request = query_params["request"]
    client_id = client_id_from_request(conn)

    user_params = %{
      email: email
    }

    Accounts.send_reset_password_instructions(
      conn,
      client_id,
      user_params,
      &Routes.user_reset_password_url(conn, :edit, &1, %{request: request}),
      __MODULE__
    )
  end

  def edit(conn, params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_password_reset(conn, client_id, params["token"], __MODULE__)
  end

  def update(conn, params) do
    client_id = client_id_from_request(conn)

    user_params = Map.get(params, "user", %{})

    reset_password_params = %{
      reset_password_token: params["token"],
      password: user_params["password"],
      password_confirmation: user_params["password_confirmation"]
    }

    Accounts.reset_password(conn, client_id, reset_password_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_instructions_initialized(
        %Plug.Conn{query_params: query_params} = conn,
        relying_party,
        template
      ) do
    request = query_params["request"]

    render(conn, "new.html",
      template: compile_template(template, %{relying_party: relying_party, request: request})
    )
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def reset_password_instructions_delivered(%Plug.Conn{query_params: query_params} = conn) do
    request = query_params["request"]

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def invalid_relying_party(%Plug.Conn{query_params: query_params} = conn, %RelyingPartyError{
        message: message
      }) do
    request = query_params["request"]

    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_initialized(
        %Plug.Conn{query_params: query_params} = conn,
        token,
        relying_party,
        template
      ) do
    request = query_params["request"]

    render(conn, "edit.html",
      template:
        compile_template(template, %{relying_party: relying_party, request: request, token: token})
    )
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reseted(%Plug.Conn{query_params: query_params} = conn, _user) do
    request = query_params["request"]

    # Do not log in the user after reset password to avoid a
    # leaked token giving the user access to the account.
    conn
    |> put_flash(:info, "Password reset successfully.")
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_failure(%Plug.Conn{query_params: query_params} = conn, %ResetPasswordError{
        relying_party: relying_party,
        template: template,
        changeset: %Ecto.Changeset{} = changeset,
        token: token
      }) do
    request = query_params["request"]

    conn
    |> render("edit.html",
      template:
        compile_template(template, %{
          valid?: false,
          relying_party: relying_party,
          request: request,
          changeset: changeset,
          token: token
        })
    )
  end

  @impl BorutaIdentity.Accounts.ResetPasswordApplication
  def password_reset_failure(%Plug.Conn{query_params: query_params} = conn, %ResetPasswordError{
        message: message
      }) do
    request = query_params["request"]

    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end

  defp compile_template(%Template{content: content}, opts) do
    request = Map.fetch!(opts, :request)

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
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      update_user_reset_password_path:
        Routes.user_reset_password_path(
          BorutaIdentityWeb.Endpoint,
          :update,
          Map.get(opts, :token, ""),
          %{request: request}
        ),
      new_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      valid?: Map.get(opts, :valid?, true),
      errors: errors,
      registrable?: Map.fetch!(opts, :relying_party).registrable
    }

    Mustachex.render(content, context)
  end
end
