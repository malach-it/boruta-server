defmodule BorutaIdentityWeb.TotpController do
  @behaviour BorutaIdentity.TotpRegistrationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      client_id_from_request: 1
    ]

  alias BorutaIdentity.Totp
  alias BorutaIdentity.TotpError
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Totp.initialize_totp_registration(conn, client_id, __MODULE__)
  end

  def register(conn, %{"totp" => totp_params}) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns.current_user

    totp_params = %{
      totp_code: totp_params["totp_code"],
      totp_secret: totp_params["totp_secret"]
    }

    Totp.register_totp(conn, client_id, current_user, totp_params, __MODULE__)
  end

  @impl BorutaIdentity.TotpRegistrationApplication
  def totp_registration_initialized(conn, totp_secret, template) do
    current_user = conn.assigns.current_user

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        current_user: current_user,
        totp_secret: totp_secret
      }
    )
  end

  @impl BorutaIdentity.TotpRegistrationApplication
  def totp_registration_error(conn, %TotpError{
        changeset: %Ecto.Changeset{} = changeset,
        totp_secret: totp_secret,
        template: template
      }) do
    current_user = conn.assigns.current_user

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        changeset: changeset,
        current_user: current_user,
        totp_secret: totp_secret
      }
    )
  end

  def totp_registration_error(conn, %TotpError{
        message: error,
        totp_secret: totp_secret,
        template: template
      }) do
    current_user = conn.assigns.current_user

    conn
    |> put_layout(false)
    |> put_status(:unprocessable_entity)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [error],
        current_user: current_user,
        totp_secret: totp_secret
      }
    )
  end

  @impl BorutaIdentity.TotpRegistrationApplication
  def totp_registration_success(%Plug.Conn{query_params: query_params} = conn, _user) do
    conn
    |> put_flash(:info, "TOTP authenticator registered successfully.")
    |> redirect(
      to: Routes.choose_session_path(conn, :index, request: Map.get(query_params, "request"))
    )
  end
end
