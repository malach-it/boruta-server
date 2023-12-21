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
      label: organization.label
    }
  end

  def render("show_email_template.json", %{email_template: template}) do
    %{data: render_one(template, __MODULE__, "email_template.json", template: template)}
  end

  def render("email_template.json", %{template: template}) do
    %{
      id: template.id,
      txt_content: template.txt_content,
      html_content: template.html_content,
      type: template.type,
      organization_id: template.organization_id
    }
  end
end
