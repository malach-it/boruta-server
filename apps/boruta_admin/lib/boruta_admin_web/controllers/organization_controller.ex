defmodule BorutaAdminWeb.OrganizationController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.Accounts.EmailTemplate
  alias BorutaIdentity.Admin
  alias BorutaIdentity.Organizations
  alias BorutaIdentity.Organizations.Organization

  plug(:authorize, ["users:manage:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, params) do
    organizations =
      case params["q"] do
        nil -> Admin.list_organizations(params)
        # query -> Admin.search_organizations(query, params)
      end

    render(conn, "index.json",
      organizations: organizations.entries,
      page_number: organizations.page_number,
      page_size: organizations.page_size,
      total_pages: organizations.total_pages,
      total_entries: organizations.total_entries
    )
  end

  def show(conn, %{"id" => id}) do
    case Admin.get_organization(id) do
      %Organization{} = organization ->
        render(conn, "show.json", organization: organization)

      nil ->
        {:error, :not_found}
    end
  end

  def create(conn, %{"organization" => organization_params}) do
    create_params = %{
      name: organization_params["name"],
      label: organization_params["label"],
    }

    with {:ok, organization} <- Admin.create_organization(create_params) do
      render(conn, "show.json", organization: organization)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def update(conn, %{"id" => id, "organization" => organization_params}) do
    update_params = %{
      name: organization_params["name"],
      label: organization_params["label"],
    }

    with :ok <- ensure_open_for_edition(id, conn),
         %Organization{} = organization <- Admin.get_organization(id),
         {:ok, %Organization{} = organization} <-
           Admin.update_organization(organization, update_params) do
      render(conn, "show.json", organization: organization)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def update(_conn, _params), do: {:error, :bad_request}

  def delete(conn, %{"id" => organization}) do
    with :ok <- ensure_open_for_edition(organization, conn),
         {:ok, _organization} <- Admin.delete_organization(organization) do
      send_resp(conn, 204, "")
    end
  end

  def email_template(conn, %{"organization_id" => id, "template_type" => template_type}) do
    dbg id
    template = Organizations.get_organization_email_template!(id, String.to_atom(template_type))
    render(conn, "show_email_template.json", email_template: template)
  end

  def update_email_template(conn, %{
        "organization_id" => id,
        "template_type" => template_type,
        "template" => template_params
      }) do
    template = Organizations.get_organization_email_template!(id, String.to_atom(template_type))

    with {:ok, %EmailTemplate{} = template} <-
           Organizations.upsert_email_template(template, template_params) do
      render(conn, "show_email_template.json", email_template: template)
    end
  end

  def delete_email_template(conn, %{"organization_id" => id, "template_type" => template_type}) do
    template = Organizations.delete_email_template!(id, String.to_atom(template_type))
    render(conn, "show_email_template.json", email_template: template)
  end

  defp ensure_open_for_edition(_user_id, _conn) do
    :ok
  end
end
