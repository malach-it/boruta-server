defmodule BorutaAdmin.ConfigurationLoaderTest do
  use BorutaAdmin.DataCase

  alias Boruta.Ecto.Client
  alias Boruta.Ecto.Scope
  alias BorutaAdmin.ConfigurationLoader
  alias BorutaGateway.Upstreams.Upstream
  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Configuration.ErrorTemplate

  test "returns an error with a bad configuration file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:error, "Bad configuration file."}
  end

  test "returns an error with a bad gateway configuration file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_gateway_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                gateway: ["Required properties scheme, host, port, uris are missing at #."]
              }}
  end

  test "returns an error with a bad microgateway configuration file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_microgateway_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                gateway: [],
                microgateway: [
                  "Required properties scheme, host, port, uris are missing at #."
                ]
              }}
  end

  test "returns an error with a bad identity provider configuration file" do
    assert BorutaIdentity.Repo.all(IdentityProvider) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_identity_provider_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                identity_provider: ["Schema does not allow additional properties: #/additional."]
              }}
  end

  test "returns an error with a bad backend configuration file" do
    assert BorutaIdentity.Repo.all(Backend) |> Enum.count() == 1

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_backend_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                backend: ["Schema does not allow additional properties: #/additional."]
              }}
  end

  test "returns an error with a bad client configuration file" do
    assert BorutaAuth.Repo.all(Client) |> Enum.count() == 1

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_client_configuration.yml")

    assert {:ok,
            %{
              client: [
                %Ecto.Changeset{
                  errors: [identity_provider_id: {"can't be blank", [validation: :required]}]
                }
              ]
            }} = ConfigurationLoader.from_file!(configuration_file_path)
  end

  test "returns an error with a bad scope configuration file" do
    assert BorutaAuth.Repo.all(Scope) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_scope_configuration.yml")

    assert {:ok,
            %{
              scope: [
                %Ecto.Changeset{errors: [name: {"can't be blank", [validation: :required]}]}
              ]
            }} = ConfigurationLoader.from_file!(configuration_file_path)
  end

  test "returns an error with a bad role configuration file" do
    assert BorutaIdentity.Repo.all(Role) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_role_configuration.yml")

    assert {:ok,
            %{
              role: [%Ecto.Changeset{errors: [name: {"can't be blank", [validation: :required]}]}]
            }} = ConfigurationLoader.from_file!(configuration_file_path)
  end

  test "returns an error with a bad error template configuration file" do
    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_error_template_configuration.yml")

    assert {:ok,
            %{
              error_template: ["Error template does not exist."]
            }} = ConfigurationLoader.from_file!(configuration_file_path)
  end

  test "loads a file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    Application.delete_env(ConfigurationLoader, :node_name)

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/full_configuration.yml")

    ConfigurationLoader.from_file!(configuration_file_path)

    assert [
             %Upstream{
               scheme: "http",
               host: "httpbin.patatoid.fr",
               port: 80,
               uris: ["/httpbin"],
               required_scopes: %{"GET" => ["test"]},
               strip_uri: true,
               authorize: true,
               pool_size: 10,
               pool_count: 1,
               max_idle_time: 10,
               error_content_type: "test",
               forbidden_response: "test",
               unauthorized_response: "test",
               forwarded_token_signature_alg: "HS384",
               forwarded_token_secret: "test",
               forwarded_token_public_key: nil,
               forwarded_token_private_key: nil
             },
             %Upstream{
               node_name: "nonode@nohost",
               scheme: "http",
               host: "httpbin.patatoid.fr",
               port: 80,
               uris: ["/httpbin"],
               required_scopes: %{"GET" => ["test"]},
               strip_uri: true,
               authorize: true,
               pool_size: 10,
               pool_count: 1,
               max_idle_time: 10,
               error_content_type: "test",
               forbidden_response: "test",
               unauthorized_response: "test",
               forwarded_token_signature_alg: "HS384",
               forwarded_token_secret: "test",
               forwarded_token_public_key: nil,
               forwarded_token_private_key: nil
             }
           ] = BorutaGateway.Repo.all(Upstream)

    # TODO test all possible configurations
    assert %Backend{name: "test"} = BorutaIdentity.Repo.all(Backend) |> List.last()

    assert %IdentityProvider{
             name: "test",
             templates: [%Template{content: "test", type: "layout"}]
           } =
             BorutaIdentity.Repo.all(IdentityProvider)
             |> List.last()
             |> BorutaIdentity.Repo.preload(:templates)

    assert %Client{name: "test"} = BorutaAuth.Repo.all(Client) |> List.last()

    assert %Scope{name: "test"} = BorutaAuth.Repo.all(Scope) |> List.last()

    assert %Role{name: "test"} = BorutaIdentity.Repo.all(Role) |> List.last()

    assert %ErrorTemplate{type: "500", content: "test"} =
             BorutaIdentity.Repo.all(ErrorTemplate) |> List.last()
  end
end
