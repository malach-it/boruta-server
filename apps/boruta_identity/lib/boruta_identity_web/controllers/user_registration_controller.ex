defmodule BorutaIdentityWeb.UserRegistrationController do
  @behaviour BorutaIdentity.Accounts.RegistrationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [store_user_session: 2, after_registration_path: 1, client_id_from_request: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RegistrationError
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_registration(conn, client_id, __MODULE__)
  end

  def create(%Plug.Conn{query_params: query_params} = conn, %{"user" => user_params}) do
    client_id = client_id_from_request(conn)
    request = query_params["request"]

    Accounts.register(
      conn,
      client_id,
      user_params,
      &Routes.user_confirmation_url(conn, :confirm, &1, %{request: request}),
      __MODULE__
    )
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def registration_initialized(%Plug.Conn{} = conn, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html", template: template, assigns: %{})
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def registration_failure(%Plug.Conn{} = conn, %RegistrationError{
        changeset: %Ecto.Changeset{} = changeset,
        template: template
      }) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        changeset: changeset
      }
    )
  end

  @impl BorutaIdentity.Accounts.RegistrationApplication
  def user_registered(conn, _user, session_token) do
    conn
    |> store_user_session(session_token)
    |> redirect(to: after_registration_path(conn))
  end
end
