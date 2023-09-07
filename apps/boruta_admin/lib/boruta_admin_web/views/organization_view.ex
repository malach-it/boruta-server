defmodule BorutaAdminWeb.OrganizationView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.OrganizationView

  def render("index.json", %{
        organizations: organizations,
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      data: render_many(organizations, OrganizationView, "organization.json"),
      page_number: page_number,
      page_size: page_size,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{organization: organization}) do
    %{data: render_one(organization, OrganizationView, "organization.json")}
  end

  def render("organization.json", %{organization: organization}) do
    %{
      id: organization.id,
      name: organization.name,
      label: "label"
    }
  end
end
