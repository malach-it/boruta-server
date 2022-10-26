defmodule BorutaAdminWeb.BackendController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["identity-providers:manage:all"])

  def index(conn, _params) do
    backends = IdentityProviders.list_backends()
    render(conn, "index.json", backends: backends)
  end

  def create(conn, %{"backend" => backend_params}) do
    with {:ok, %Backend{} = backend} <-
           IdentityProviders.create_backend(backend_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.admin_backend_path(conn, :show, backend))
      |> render("show.json", backend: backend)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def show(conn, %{"id" => id}) do
    backend = IdentityProviders.get_backend!(id)
    render(conn, "show.json", backend: backend)
  end

  def update(conn, %{"id" => id, "backend" => backend_params}) do
    backend = IdentityProviders.get_backend!(id)

    with {:ok, %Backend{} = backend} <-
           IdentityProviders.update_backend(backend, backend_params) do
      render(conn, "show.json", backend: backend)
    end
  end

  def update(_conn, _params), do: {:error, :bad_request}

  def delete(conn, %{"id" => id}) do
    backend = IdentityProviders.get_backend!(id)

    # with :ok <- ensure_open_for_edition(id),
    with {:ok, %Backend{}} <- IdentityProviders.delete_backend(backend) do
      send_resp(conn, :no_content, "")
    end
  end

  def email_template(conn, %{"backend_id" => id, "template_type" => template_type}) do
    template = IdentityProviders.get_backend_email_template!(id, String.to_atom(template_type))
    render(conn, "show_email_template.json", email_template: template)
  end

  def update_email_template(conn, %{
        "backend_id" => id,
        "template_type" => template_type,
        "template" => template_params
      }) do
    template = IdentityProviders.get_backend_email_template!(id, String.to_atom(template_type))

    with {:ok, %EmailTemplate{} = template} <-
           IdentityProviders.upsert_email_template(template, template_params) do
      render(conn, "show_email_template.json", email_template: template)
    end
  end

  def delete_email_template(conn, %{"backend_id" => id, "template_type" => template_type}) do
    template = IdentityProviders.delete_email_template!(id, String.to_atom(template_type))
    render(conn, "show_email_template.json", email_template: template)
  end

  # TODO client backend association
  # defp ensure_open_for_edition(backend_id) do
  #   admin_ui_client_id =
  #     System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "6a2f41a3-c54c-fce8-32d2-0324e1c32e20")

  #   case IdentityProviders.get_backend_by_client_id(admin_ui_client_id) do
  #     %Backend{id: ^backend_id} ->
  #       {:error, :protected_resource}
  #     _ ->
  #       :ok
  #   end
  # end
end
