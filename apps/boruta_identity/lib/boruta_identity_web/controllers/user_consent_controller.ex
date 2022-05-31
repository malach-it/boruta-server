defmodule BorutaIdentityWeb.UserConsentController do
  @behaviour BorutaIdentity.Accounts.ConsentApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1, scope_from_request: 1, after_sign_in_path: 1]

  import BorutaIdentityWeb.ErrorHelpers

  alias BorutaIdentity.Accounts
  alias BorutaIdentityWeb.ChangesetView
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
      client_id: params["client_id"],
      scopes: params["scopes"]
    }

    Accounts.consent(conn, client_id, current_user, consent_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_not_required(conn) do
    redirect(conn, to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consented(conn) do
    redirect(conn, to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def consent_failed(%Plug.Conn{query_params: query_params} = conn, changeset) do
    error_messages = changeset |> ChangesetView.translate_errors() |> errors_tag()
    request = query_params["request"]

    conn
    |> put_flash(:error, error_messages)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
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
end
