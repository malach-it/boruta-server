defmodule BorutaIdentityWeb.UserConsentController do
  @behaviour BorutaIdentity.Accounts.ConsentApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1, scope_from_request: 1, after_sign_in_path: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentityWeb.ErrorHelpers
  alias BorutaIdentityWeb.TemplateView

  action_fallback(BorutaIdentityWeb.FallbackController)

  def index(conn, _params) do
    current_user = conn.assigns[:current_user]
    client_id = client_id_from_request(conn)
    scope = scope_from_request(conn)

    Accounts.initialize_consent(conn, client_id, current_user, scope, __MODULE__)
  end

  def consent(conn, params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    consent_params = %{
      client_id: client_id,
      scopes: params["scopes"] || []
    }

    Accounts.consent(conn, client_id, current_user, consent_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_initialized(conn, client, scopes, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        scopes: scopes,
        client: client
      }
    )
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_not_required(conn) do
    redirect(conn, to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consented(conn, scopes) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authorization, :consent, :success],
      %{},
      %{
        client_id: client_id,
        sub: current_user.uid,
        provider: current_user.provider,
        scopes: scopes
      }
    )

    redirect(conn, to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_failed(%Plug.Conn{query_params: query_params} = conn, changeset) do
    message = ErrorHelpers.error_messages(changeset) |> Enum.join(", ")
    request = query_params["request"]
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authorization, :consent, :failure],
      %{},
      %{
        client_id: client_id,
        sub: current_user.uid,
        provider: current_user.provider,
        scopes: Ecto.Changeset.get_field(changeset, :scopes),
        message: message
      }
    )

    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end
end
