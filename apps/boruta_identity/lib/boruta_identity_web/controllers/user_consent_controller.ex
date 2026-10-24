defmodule BorutaIdentityWeb.UserConsentController do
  @behaviour BorutaIdentity.Accounts.ConsentApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1, scope_from_request: 1, after_sign_in_path: 1]

  alias Boruta.Oauth.Scope
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
    with request when is_binary(request) and request != "" <- conn.query_params["request"],
         client_id when is_binary(client_id) <- client_id_from_request(conn),
         scope when is_binary(scope) <- scope_from_request(conn) do
      current_user = conn.assigns[:current_user]
      requested_scopes = Scope.split(scope)

      consent_params =
            %{
              client_id: client_id,
              scopes: Enum.filter(scopes, &is_binary/1) || []
            }

      Accounts.consent(
        conn,
        client_id,
        current_user,
        requested_scopes,
        consent_params,
        __MODULE__
      )
    else
      _ -> send_resp(conn, :conflict, "Authorization request changed. Restart consent.")
    end
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
        sub: current_user.id,
        backend: current_user.backend,
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
        sub: current_user.id,
        backend: current_user.backend,
        scopes: Ecto.Changeset.get_field(changeset, :scopes),
        message: message
      }
    )

    conn
    |> put_flash(:error, message)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end
end
