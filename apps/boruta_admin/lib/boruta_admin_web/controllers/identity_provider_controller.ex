defmodule BorutaAdminWeb.IdentityProviderController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["identity-providers:manage:all"])

  def index(conn, _params) do
    identity_providers = IdentityProviders.list_identity_providers()
    render(conn, "index.json", identity_providers: identity_providers)
  end

  def create(conn, %{"identity_provider" => identity_provider_params}) do
    with {:ok, %IdentityProvider{} = identity_provider} <-
           IdentityProviders.create_identity_provider(identity_provider_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_identity_provider_path(conn, :show, identity_provider))
      |> render("show.json", identity_provider: identity_provider)
    end
  end

  def show(conn, %{"id" => id}) do
    identity_provider = IdentityProviders.get_identity_provider!(id)
    render(conn, "show.json", identity_provider: identity_provider)
  end

  def template(conn, %{"identity_provider_id" => id, "template_type" => template_type}) do
    template = IdentityProviders.get_identity_provider_template!(id, String.to_atom(template_type))
    render(conn, "show_template.json", template: template)
  end

  def update(conn, %{"id" => id, "identity_provider" => identity_provider_params}) do
    identity_provider = IdentityProviders.get_identity_provider!(id)

    with {:ok, %IdentityProvider{} = identity_provider} <-
           IdentityProviders.update_identity_provider(identity_provider, identity_provider_params) do
      render(conn, "show.json", identity_provider: identity_provider)
    end
  end

  def update_template(conn, %{
        "identity_provider_id" => id,
        "template_type" => template_type,
        "template" => template_params
      }) do
    template = IdentityProviders.get_identity_provider_template!(id, String.to_atom(template_type))

    with {:ok, %Template{} = template} <-
           IdentityProviders.upsert_template(template, template_params) do
      render(conn, "show_template.json", template: template)
    end
  end

  def delete_template(conn, %{"identity_provider_id" => id, "template_type" => template_type}) do
    template = IdentityProviders.delete_identity_provider_template!(id, String.to_atom(template_type))
    render(conn, "show_template.json", template: template)
  end

  def delete(conn, %{"id" => id}) do
    identity_provider = IdentityProviders.get_identity_provider!(id)

    with :ok <- ensure_open_for_edition(id),
         {:ok, %IdentityProvider{}} <- IdentityProviders.delete_identity_provider(identity_provider) do
      send_resp(conn, :no_content, "")
    end
  end

  defp ensure_open_for_edition(identity_provider_id) do
    admin_ui_client_id =
      System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")

    case IdentityProviders.get_identity_provider_by_client_id(admin_ui_client_id) do
      %IdentityProvider{id: ^identity_provider_id} ->
        {:error, :protected_resource}
      _ ->
        :ok
    end
  end
end
