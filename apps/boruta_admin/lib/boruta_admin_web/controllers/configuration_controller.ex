defmodule BorutaAdminWeb.ConfigurationController do
  use BorutaAdminWeb, :controller

  import Boruta.Config, only: [issuer: 0]

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaAdmin.ConfigurationLoader
  alias BorutaAdmin.Configurations
  alias BorutaIdentity.Configuration
  alias BorutaIdentity.Configuration.ErrorTemplate

  action_fallback(BorutaAdminWeb.FallbackController)

  plug(:authorize, ["configuration:manage:all"])

  @resource %{
    "client" => "clients",
    "identity_provider" => "identity-providers",
    "backend" => "identity-providers",
    "role" => "scopes",
    "scope" => "scopes",
    "gateway" => "upstreams",
    "microgateway" => "upstreams",
    "error_template" => "configuration"
  }

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

  def example_configuration_file(conn, _params) do
    content =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/examples/configuration.yml")
      |> File.read!()

    content =
      String.replace(
        content,
        "{{PREAUTHORIZED_CODE_REDIRECT_URI}}",
        issuer() <>
          # credo:disable-for-next-line
          BorutaIdentityWeb.Router.Helpers.wallet_path(BorutaIdentityWeb.Endpoint, :index) <>
          "/preauthorized-code"
      )

    content =
      String.replace(
        content,
        "{{PRESENTATION_REDIRECT_URI}}",
        issuer() <>
          # credo:disable-for-next-line
          BorutaIdentityWeb.Router.Helpers.wallet_path(BorutaIdentityWeb.Endpoint, :index) <>
          "/verifiable-presentation"
      )

    configurations = [
      %{
        name: "configuration_file",
        value: content
      }
    ]

    render(conn, "configuration.json", configurations: configurations)
  end

  def configuration(conn, _params) do
    configurations = Configurations.list_configurations()

    render(conn, "configuration.json", configurations: configurations)
  end

  def upload_configuration_file(conn, %{"file" => %Plug.Upload{path: path}}) do
    file_content = File.read!(path)

    with %{"configuration" => %{} = configuration, "version" => "1.0"} <-
           YamlElixir.read_from_file!(path),
         configuration <- filter_configuration(configuration, conn.assigns[:authorization]),
         result <- ConfigurationLoader.load_configuration(configuration) do
      # TODO perform a transaction
      Configurations.upsert_configuration("configuration_file", file_content)
      render(conn, "file_upload.json", result: result, file_content: file_content)
    else
      _ ->
        {:error, :bad_request}
    end
  end

  defp filter_configuration(configuration, %{"scope" => scope}) do
    Enum.filter(configuration, fn {key, _value} ->
      Regex.match?(~r{#{@resource[key]}:manage:all}, scope)
    end)
    |> Enum.into(%{})
  end
end
