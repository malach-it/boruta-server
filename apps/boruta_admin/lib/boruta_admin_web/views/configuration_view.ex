defmodule BorutaAdminWeb.ConfigurationView do
  use BorutaAdminWeb, :view
  def render("show_error_template.json", %{template: template}) do
    %{data: render_one(template, __MODULE__, "error_template.json", template: template)}
  end

  def render("error_template.json", %{template: template}) do
    %{
      id: template.id,
      content: template.content,
      type: template.type,
    }
  end
end
