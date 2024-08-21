defmodule BorutaIdentityWeb.WebauthnController do
  @behaviour BorutaIdentity.WebauthnRegistrationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      get_user_session: 1,
      client_id_from_request: 1,
      after_sign_in_path: 1
    ]

  alias BorutaIdentity.Webauthn
  alias BorutaIdentity.WebauthnError
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    Webauthn.initialize_webauthn_registration(conn, client_id, current_user, __MODULE__)
  end

  def register(conn, params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    webauthn_params = %{
      attestation: params["attestation"],
      client_data: params["client_data"],
      identifier: params["identifier"],
      type: params["type"]
    }

    Webauthn.register_webauthn(conn, client_id, current_user, webauthn_params, __MODULE__)
  end

  @impl BorutaIdentity.WebauthnRegistrationApplication
  def webauthn_registration_initialized(conn, webauthn_options, template) do
    current_user = conn.assigns[:current_user]

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        current_user: current_user,
        webauthn_options: webauthn_options
      }
    )
  end

  @impl BorutaIdentity.WebauthnRegistrationApplication
  def webauthn_registration_error(conn, %WebauthnError{
        message: message,
        webauthn_options: webauthn_options,
        template: template
      }) do
    current_user = conn.assigns[:current_user]

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message],
        webauthn_options: webauthn_options,
        current_user: current_user
      }
    )
  end

  @impl BorutaIdentity.WebauthnRegistrationApplication
  def webauthn_registration_success(%Plug.Conn{} = conn, _user) do
    conn
    |> put_flash(:info, "Passkey registered successfully.")
    |> put_session(
      :webauthn_authenticated,
      (get_session(conn, :webauthn_authenticated) || %{})
      |> Map.put(get_user_session(conn), true)
    )
    |> redirect(to: after_sign_in_path(conn))
  end
end
