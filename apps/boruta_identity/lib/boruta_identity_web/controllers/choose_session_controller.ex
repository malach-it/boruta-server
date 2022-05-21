defmodule BorutaIdentityWeb.ChooseSessionController do
  @behaviour BorutaIdentity.Accounts.ChooseSessionApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentityWeb.TemplateView

  def index(conn, _params) do
    client_id = client_id_from_request(conn)

    Accounts.initialize_choose_session(conn, client_id, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.ChooseSessionApplication
  def choose_session_initialized(conn, template) do
    current_user = conn.assigns[:current_user]

    conn
    |> put_session(:session_chosen, true)
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html", template: template, assigns: %{current_user: current_user})
  end

  @impl BorutaIdentity.Accounts.ChooseSessionApplication
  def choose_session_not_required(conn) do
    conn
    |> put_session(:session_chosen, true)
    |> redirect(to: Routes.user_session_path(conn, :new, conn.query_params))
  end

  @impl BorutaIdentity.Accounts.ChooseSessionApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end
end
