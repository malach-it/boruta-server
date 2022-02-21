defmodule BorutaIdentityWeb.ChooseSessionController do
  @behaviour BorutaIdentity.Accounts.ChooseSessionApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.RelyingParties.Template

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
    |> render("new.html", template: compile_template(template, %{conn: conn, current_user: current_user}))
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

  defp compile_template(%Template{layout: layout, content: content}, opts) do
    %Plug.Conn{query_params: query_params} = conn = Map.fetch!(opts, :conn)
    request = Map.get(query_params, "request")
    current_user = Map.fetch!(opts, :current_user) |> Map.from_struct()

    messages =
      get_flash(conn)
      |> Enum.map(fn {type, value} ->
        %{
          "type" => type,
          "content" => value
        }
      end)

    context = %{
      new_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      delete_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request}),
      current_user: current_user,
      messages: messages
    }

    Mustachex.render(layout.content, context, partials: %{inner_content: content})
  end
end
