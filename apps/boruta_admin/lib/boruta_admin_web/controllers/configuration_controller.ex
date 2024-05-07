defmodule BorutaAdminWeb.ConfigurationController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaIdentity.Configuration
  alias BorutaAdmin.ConfigurationLoader
  alias BorutaIdentity.Configuration.ErrorTemplate

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["configuration:manage:all"])

  def error_template(conn, %{"template_type" => template_type}) do
    template = Configuration.get_error_template!(String.to_integer(template_type))
    render(conn, "show_error_template.json", template: template)
  end

  def update_error_template(conn, %{
        "template_type" => template_type,
        "template" => template_params
      }) do
    template = Configuration.get_error_template!(String.to_integer(template_type))

    with {:ok, %ErrorTemplate{} = template} <-
           Configuration.upsert_error_template(template, template_params) do
      render(conn, "show_error_template.json", template: template)
    end
  end

  def delete_error_template(conn, %{"template_type" => template_type}) do
    template = Configuration.delete_error_template!(String.to_integer(template_type))
    render(conn, "show_error_template.json", template: template)
  end

  def upload_configuration_file(conn, %{"file" => %Plug.Upload{path: path}}) do
    case YamlElixir.read_from_file(path) do
      {:ok, %{"configuration" => configuration}} ->
        dbg(configuration)
        result = ConfigurationLoader.load_configuration(configuration) |> dbg

        render(conn, "file_upload.json", result: result, file_content: File.read!(path))
      {:error, _error} ->
        {:error, :bad_request}
    end
  end
end
