defmodule BorutaIdentityWeb.UserSessionController do
  @behaviour BorutaIdentity.Accounts.SessionApplication
  @behaviour BorutaIdentity.TotpAuthenticationApplication
  @behaviour BorutaIdentity.WebauthnAuthenticationApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      store_user_session: 2,
      get_user_session: 1,
      remove_user_session: 1,
      after_sign_in_path: 1,
      after_sign_out_path: 1,
      client_id_from_request: 1
    ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Totp
  alias BorutaIdentity.TotpError
  alias BorutaIdentity.Webauthn
  alias BorutaIdentity.WebauthnError
  alias BorutaIdentityWeb.TemplateView

  def new(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_session(conn, client_id, __MODULE__)
  end

  def create(conn, %{"user" => user_params}) do
    client_id = client_id_from_request(conn)

    authentication_params = %{
      email: user_params["email"],
      password: user_params["password"]
    }

    Accounts.create_session(conn, client_id, authentication_params, __MODULE__)
  end

  def delete(conn, _params) do
    client_id = client_id_from_request(conn)
    session_token = get_user_session(conn)

    Accounts.delete_session(conn, client_id, session_token, __MODULE__)
  end

  def initialize_totp(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    conn
    |> Totp.initialize_totp(client_id, current_user, __MODULE__)
  end

  def authenticate_totp(conn, %{"totp" => totp_params}) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    totp_params = %{
      totp_code: totp_params["totp_code"]
    }

    Totp.authenticate_totp(conn, client_id, current_user, totp_params, __MODULE__)
  end

  def initialize_webauthn(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    conn
    |> Webauthn.initialize_webauthn(client_id, current_user, __MODULE__)
  end

  def authenticate_webauthn(conn, params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    webauthn_params = %{
      signature: params["signature"],
      authenticator_data: params["authenticator_data"],
      client_data: params["client_data"],
      identifier: params["identifier"],
      type: params["type"]
    }

    Webauthn.authenticate_webauthn(conn, client_id, current_user, webauthn_params, __MODULE__)
  end

  @impl BorutaIdentity.WebauthnAuthenticationApplication
  def webauthn_registration_missing(%Plug.Conn{query_params: query_params} = conn) do
    conn
    |> put_flash(:warning, "You need to register a TOTP authenticator before continue.")
    |> redirect(
      to: Routes.webauthn_path(BorutaIdentityWeb.Endpoint, :new, %{request: query_params["request"]})
    )
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def session_initialized(%Plug.Conn{} = conn, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{}
    )
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def user_authenticated(conn, user, session_token) do
    client_id = client_id_from_request(conn)

    :telemetry.execute(
      [:authentication, :log_in, :success],
      %{},
      %{
        sub: user.uid,
        backend: user.backend,
        client_id: client_id
      }
    )

    conn
    |> store_user_session(session_token)
    |> Totp.initialize_totp(client_id, user, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def authentication_failure(%Plug.Conn{} = conn, %SessionError{
        message: message,
        template: template
      }) do
    client_id = client_id_from_request(conn)

    :telemetry.execute(
      [:authentication, :log_in, :failure],
      %{},
      %{
        message: message,
        client_id: client_id
      }
    )

    conn
    |> put_layout(false)
    |> put_status(:unauthorized)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message]
      }
    )
  end

  @impl BorutaIdentity.Accounts.SessionApplication
  def session_deleted(conn) do
    client_id = client_id_from_request(conn)
    user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authentication, :log_out, :success],
      %{},
      %{
        sub: user && user.uid,
        backend: user && user.backend,
        client_id: client_id
      }
    )

    conn
    |> remove_user_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: after_sign_out_path(conn))
  end

  @impl BorutaIdentity.TotpAuthenticationApplication
  def totp_not_required(conn) do
    conn
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.TotpAuthenticationApplication
  def totp_registration_missing(%Plug.Conn{query_params: query_params} = conn) do
    conn
    |> put_flash(:warning, "You need to register a TOTP authenticator before continue.")
    |> redirect(
      to: Routes.totp_path(BorutaIdentityWeb.Endpoint, :new, %{request: query_params["request"]})
    )
  end

  @impl BorutaIdentity.TotpAuthenticationApplication
  def totp_initialized(%Plug.Conn{} = conn, template) do
    current_user = conn.assigns[:current_user]

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        current_user: current_user
      }
    )
  end

  @impl BorutaIdentity.WebauthnAuthenticationApplication
  def webauthn_initialized(%Plug.Conn{} = conn, webauthn_options, template) do
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

  @impl BorutaIdentity.TotpAuthenticationApplication
  def totp_authenticated(%Plug.Conn{} = conn, _user) do
    conn
    |> put_session(
      :totp_authenticated,
      (get_session(conn, :totp_authenticated) || %{})
      |> Map.put(get_user_session(conn), true)
    )
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.TotpAuthenticationApplication
  def totp_authentication_failure(%Plug.Conn{} = conn, %TotpError{
        message: message,
        template: template
      }) do
    current_user = conn.assigns.current_user

    conn
    |> put_layout(false)
    |> put_status(:unauthorized)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message],
        current_user: current_user
      }
    )
  end

  @impl BorutaIdentity.WebauthnAuthenticationApplication
  def webauthn_not_required(conn) do
    conn
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.WebauthnAuthenticationApplication
  def webauthn_authenticated(%Plug.Conn{} = conn, _user) do
    conn
    |> put_session(
      :webauthn_authenticated,
      (get_session(conn, :webauthn_authenticated) || %{})
      |> Map.put(get_user_session(conn), true)
    )
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.WebauthnAuthenticationApplication
  def webauthn_authentication_failure(%Plug.Conn{} = conn, %WebauthnError{
        message: message,
        webauthn_options: webauthn_options,
        template: template
      }) do
    current_user = conn.assigns.current_user

    conn
    |> put_layout(false)
    |> put_status(:unauthorized)
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
end
