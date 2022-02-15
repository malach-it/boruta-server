defmodule BorutaIdentityWeb.ConsentController do
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [client_id_from_request: 1, after_sign_in_path: 1]
  import BorutaIdentityWeb.ErrorHelpers

  alias BorutaIdentity.Accounts
  alias BorutaIdentityWeb.ChangesetView

  action_fallback(BorutaIdentityWeb.FallbackController)

  def consent(conn, params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]
    consent_params = %{
      client_id: params["client_id"],
      scopes: params["scopes"]
    }

    Accounts.consent(conn, client_id, current_user, consent_params, __MODULE__)
  end

  def consented(conn) do
    redirect(conn, to: after_sign_in_path(conn))
  end

  def consent_failed(%Plug.Conn{query_params: query_params} = conn, changeset) do
    error_messages = changeset |> ChangesetView.translate_errors() |> errors_tag()
    request = query_params["request"]

    conn
    |> put_flash(:error, error_messages)
    |> redirect(to: Routes.user_session_path(conn, :new, %{request: request}))
  end
end
