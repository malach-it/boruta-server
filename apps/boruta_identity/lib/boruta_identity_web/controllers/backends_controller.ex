defmodule BorutaIdentityWeb.BackendsController do
  # TODO test identity federation
  @behaviour BorutaIdentity.Accounts.FederatedSessionApplication
  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      store_user_session: 2,
      after_sign_in_path: 1,
      client_id_from_request: 1
    ]

  alias BorutaIdentity.Accounts.Federated
  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.FederatedAccounts
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentityWeb.TemplateView

  def authorize(
        conn,
        %{
          "id" => backend_id,
          "federated_server_name" => federated_server_name
        } = params
      ) do
    backend = IdentityProviders.get_backend!(backend_id)

    if is_nil(client_id_from_request(conn)) do
      raise IdentityProviderError, "Client identifier not provided."
    end

    if is_nil(Backend.federated_oauth_client(backend, federated_server_name)) do
      raise IdentityProviderError, "Could not fetch associated federated server"
    end

    conn
    |> redirect(external: Backend.federated_login_url(backend, federated_server_name, params["request"]))
  end

  def callback(conn, %{
    "id" => backend_id,
    "federated_server_name" => federated_server_name
  } = params) do
    conn = assign(conn, :request, params["state"])
    client_id = client_id_from_request(conn)
    backend = IdentityProviders.get_backend!(backend_id)

    FederatedAccounts.create_federated_session(
      conn,
      client_id,
      backend,
      federated_server_name,
      params["code"] || "",
      __MODULE__
    )
  end

  @impl BorutaIdentity.Accounts.FederatedSessionApplication
  def user_authenticated(conn, user, session_token) do
    client_id = client_id_from_request(conn)

    :telemetry.execute(
      [:authentication, :log_in, :success],
      %{},
      %{
        sub: user.uid,
        backend: %{user.backend | type: Federated},
        client_id: client_id
      }
    )

    conn
    |> clear_session()
    |> store_user_session(session_token)
    |> put_session(:session_chosen, true)
    |> redirect(to: after_sign_in_path(conn))
  end

  @impl BorutaIdentity.Accounts.FederatedSessionApplication
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
    |> clear_session()
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        request: conn.query_params["state"],
        errors: [message]
      }
    )
  end
end
