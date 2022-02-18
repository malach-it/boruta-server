defmodule BorutaIdentityWeb.ConsentController do
  @behaviour BorutaIdentity.Accounts.ConsentApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [client_id_from_request: 1, scope_from_request: 1, after_sign_in_path: 1]

  import BorutaIdentityWeb.ErrorHelpers

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.ChangesetView

  action_fallback(BorutaIdentityWeb.FallbackController)

  def index(conn, _params) do
    client_id = client_id_from_request(conn)
    scope = scope_from_request(conn)

    Accounts.initialize_consent(conn, client_id, scope, __MODULE__)
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
    |> render("index.html",
      template:
        compile_template(template, %{
          conn: conn,
          scopes: scopes,
          client: client
        })
    )
  end

  @impl BorutaIdentity.Accounts.ConsentApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  defp compile_template(%Template{layout: layout, content: content}, opts) do
    %Plug.Conn{query_params: query_params} = conn = Map.fetch!(opts, :conn)
    request = Map.get(query_params, "request")
    scopes = Map.fetch!(opts, :scopes) |> Enum.map(&Map.from_struct/1)
    client = Map.fetch!(opts, :client) |> Map.from_struct()

    messages =
      get_flash(conn)
      |> Enum.map(fn {type, value} ->
        %{
          "type" => type,
          "content" => value
        }
      end)

    context = %{
      create_user_consent_path:
        Routes.consent_path(conn, :consent, %{request: request}),
      client: client,
      scopes: scopes,
      _csrf_token: Plug.CSRFProtection.get_csrf_token(),
      messages: messages
    }

    Mustachex.render(layout.content, context, partials: %{inner_content: content})
  end
end
