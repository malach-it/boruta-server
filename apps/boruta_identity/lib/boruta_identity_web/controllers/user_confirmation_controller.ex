defmodule BorutaIdentityWeb.UserConfirmationController do
  @behaviour BorutaIdentity.Accounts.ConfirmationApplication

  use BorutaIdentityWeb, :controller
  import BorutaIdentityWeb.Authenticable, only: [client_id_from_request: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.ConfirmationError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_confirmation_instructions(conn, client_id, __MODULE__)
  end

  def create(%Plug.Conn{query_params: query_params} = conn, %{"user" => %{"email" => email}}) do
    request = Map.get(query_params, "request")

    confirmation_params = %{
      email: email
    }

    Accounts.send_confirmation_instructions(
      conn,
      confirmation_params,
      &Routes.user_confirmation_url(conn, :confirm, &1, %{request: request}),
      __MODULE__
    )
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def confirm(conn, %{"token" => token}) do
    client_id = client_id_from_request(conn)

    Accounts.confirm_user(conn, client_id, token, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def user_confirmed(%Plug.Conn{query_params: query_params} = conn, _user) do
    conn
    |> put_flash(:info, "Account confirmed successfully.")
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: query_params["request"]}))
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def user_confirmation_failure(%Plug.Conn{query_params: query_params} = conn, %ConfirmationError{message: message}) do
    case conn.assigns[:current_user] do
      %User{} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.user_session_path(conn, :new, request: query_params["request"]))

      _ ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.user_session_path(conn, :new, request: query_params["request"]))
    end
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def confirmation_instructions_delivered(%Plug.Conn{query_params: query_params} = conn) do
    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: Routes.user_session_path(conn, :new, request: query_params["request"]))
  end

  @impl BorutaIdentity.Accounts.ConfirmationApplication
  def confirmation_instructions_initialized(conn, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{}
    )
  end
end
