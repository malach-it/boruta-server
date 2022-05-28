defmodule BorutaIdentityWeb.UserSettingsController do
  @behaviour BorutaIdentity.Accounts.SettingsApplication

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [
    client_id_from_request: 1
  ]

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.RelyingPartyError
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

  def update(conn, %{"user" => user_params}) do
    client_id = client_id_from_request(conn)
    current_user = conn.assigns[:current_user]
    user_update_params = %{
      email: user_params["email"],
      password: user_params["password"],
      current_password: user_params["current_password"]
    }

    Accounts.update_user(conn, client_id, current_user, user_update_params, __MODULE__)
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_updated(%Plug.Conn{query_params: query_params} = conn, _user) do
    request = Map.get(query_params, "request")

    conn
    |> put_flash(:info, "Your information has been updated.")
    |> redirect(to: Routes.user_settings_path(conn, :edit, request: request))
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def user_update_failure(%Plug.Conn{} = conn, %SettingsError{
        changeset: %Ecto.Changeset{} = changeset,
        template: template
      }) do
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
        message: error,
        template: template
      }) do
    conn
    |> put_layout(false)
    |> put_view(TemplateView)
    |> render("template.html",
      template: template,
      assigns: %{
        errors: [error]
      }
    )
  end

  @impl BorutaIdentity.Accounts.SettingsApplication
  def invalid_relying_party(conn, %RelyingPartyError{message: message}) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end
end
