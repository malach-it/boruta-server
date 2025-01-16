defmodule BorutaIdentityWeb.UserSettingsController do
  @behaviour BorutaIdentity.Accounts.SettingsApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable,
    only: [
      client_id_from_request: 1,
      get_user_session: 1,
      remove_user_session: 1,
      after_sign_out_path: 1
    ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.SettingsError
  alias BorutaIdentityWeb.TemplateView

  def edit(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    Accounts.initialize_edit_user(conn, client_id, current_user, __MODULE__)
  end

  def update(%Plug.Conn{query_params: query_params} = conn, %{"user" => user_params}) do
    request = query_params["request"]
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    user_update_params =
      user_params
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
      |> Enum.into(%{})

    Accounts.update_user(
      conn,
      client_id,
      current_user,
      user_update_params,
      &Routes.user_confirmation_url(conn, :confirm, &1, %{request: request}),
      __MODULE__
    )
  end

  def destroy(conn, _params) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]

    Accounts.destroy_user(conn, client_id, current_user, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def edit_user_initialized(conn, user, template) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html", template: template, assigns: %{current_user: user})
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

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_destroyed(conn, user) do
    client_id = client_id_from_request(conn)
    session_token = get_user_session(conn)

    :telemetry.execute(
      [:registration, :destroy, :success],
      %{},
      %{
        client_id: client_id,
        uid: user.uid,
        id: user.id,
        backend: user.backend
      }
    )

    conn
    |> remove_user_session()
    |> put_flash(:info, "User data destroyed.")
    Accounts.delete_session(conn, client_id, session_token, __MODULE__)
  end

  def session_deleted(conn) do
    client_id = client_id_from_request(conn)
    user = conn.assigns[:current_user]

    :telemetry.execute(
      [:authentication, :log_out, :success],
      %{},
      %{
        sub: user && user.uid,
        backend: user && user.backend,
        client_id: client_id
      }
    )

    conn
    |> remove_user_session()
    |> put_flash(:info, "Your data has been deleted.")
    |> redirect(to: after_sign_out_path(conn))
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_destroy_failure(%Plug.Conn{} = conn, %SettingsError{
        message: message,
        template: template
      }) do
    client_id = client_id_from_request(conn)
    user = conn.assigns[:current_user]

    :telemetry.execute(
      [:registration, :destroy, :failure],
      %{},
      %{
        client_id: client_id,
        uid: user.uid,
        id: user.id,
        backend: user.backend,
        error: message
      }
    )

    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> put_status(:unprocessable_entity)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [message]
      }
    )
  end
end
