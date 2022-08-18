defmodule BorutaIdentityWeb.UserSettingsController do
  @behaviour BorutaIdentity.Accounts.SettingsApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      client_id_from_request: 1
    ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.SettingsError
  alias BorutaIdentityWeb.TemplateView

  def edit(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    Accounts.initialize_edit_user(conn, client_id, current_user, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def edit_user_initialized(conn, user, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html", template: template, assigns: %{current_user: user})
  end

  def update(%Plug.Conn{query_params: query_params} = conn, %{"user" => user_params}) do
    request = query_params["request"]
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    user_update_params = %{
      email: user_params["email"],
      password: user_params["password"],
      current_password: user_params["current_password"]
    }

    Accounts.update_user(
      conn,
      client_id,
      current_user,
      user_update_params,
      &Routes.user_confirmation_url(conn, :confirm, &1, %{request: request}),
      __MODULE__
    )
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_updated(%Plug.Conn{query_params: query_params} = conn, user) do
    request = Map.get(query_params, "request")
    client_id = client_id_from_request(conn)

    :telemetry.execute(
      [:registration, :update, :success],
      %{},
      %{
        client_id: client_id,
        sub: user.uid,
        backend: user.backend
      }
    )

    conn
    |> put_flash(:info, "Your information has been updated.")
    |> redirect(to: Routes.user_settings_path(conn, :edit, request: request))
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_update_failure(%Plug.Conn{} = conn, %SettingsError{
        changeset: %Ecto.Changeset{} = changeset,
        template: template
      }) do
    client_id = client_id_from_request(conn)
    user = conn.assigns[:current_user]

    :telemetry.execute(
      [:registration, :update, :failure],
      %{},
      %{
        client_id: client_id,
        sub: user.uid,
        backend: user.backend,
        error: changeset
      }
    )

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        changeset: changeset
      }
    )
  end

  def user_update_failure(%Plug.Conn{} = conn, %SettingsError{
        message: message,
        template: template
      }) do
    client_id = client_id_from_request(conn)
    user = conn.assigns[:current_user]

    :telemetry.execute(
      [:registration, :update, :failure],
      %{},
      %{
        client_id: client_id,
        sub: user.uid,
        backend: user.backend,
        error: message
      }
    )

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message]
      }
    )
  end
end
