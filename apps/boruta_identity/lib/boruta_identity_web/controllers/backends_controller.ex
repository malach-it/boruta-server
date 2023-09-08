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

    conn =
      case client_id_from_request(conn) do
        nil ->
          raise IdentityProviderError, "Client identifier not provided."

        _client_id ->
          put_session(conn, :request, params["request"])
      end

    case Backend.federated_oauth_client(backend, federated_server_name) do
      nil ->
        raise IdentityProviderError, "Could not fetch associated federated server"

      _oauth_client ->
        conn
        |> redirect(external: Backend.federated_login_url(backend, federated_server_name))
    end
  end

  def callback(conn, %{"federated_server_name" => federated_server_name} = params) do
    conn = request_from_session(conn)
    client_id = client_id_from_request(conn)

    FederatedAccounts.create_federated_session(
      conn,
      client_id,
      federated_server_name,
      params["code"] || "",
      __MODULE__
    )
  end

  @impl BorutaIdentity.Accounts.FederatedSessionApplication
  def user_authenticated(conn, user, session_token) do
    conn = request_from_session(conn)
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
    conn = request_from_session(conn)
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
        errors: [message]
      }
    )
  end

  defp request_from_session(conn) do
    case get_session(conn, :request) do
      nil ->
        raise IdentityProviderError, "Could not get request information."

      request ->
        %{
          conn
          | query_params: Map.put(conn.query_params, "request", request)
        }
    end
  end
end
