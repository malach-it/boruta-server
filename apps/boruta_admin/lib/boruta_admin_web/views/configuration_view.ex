defmodule BorutaAdminWeb.ConfigurationView do
  use BorutaAdminWeb, :view

  alias BorutaAdminWeb.ChangesetView

  def render("show_error_template.json", %{template: template}) do
    %{data: render_one(template, __MODULE__, "error_template.json", template: template)}
  end

  def render("error_template.json", %{template: template}) do
    %{
      id: template.id,
      content: template.content,
      type: template.type
    }
  end

  def render("file_upload.json", %{result: result, file_content: file_content}) do
    errors = Enum.map(result, fn {key, errors} ->
      errors =
        Enum.map(errors, fn
          %Ecto.Changeset{} = changeset ->
            ChangesetView.translate_errors(changeset)

          "" <> error ->
            %{validation: [error]}
        end)

      {key, errors}
    end)
    |> Enum.into(%{})

    %{
      errors: errors,
      file_content: file_content
    }
  end
end
