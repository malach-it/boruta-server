defmodule BorutaAdmin.ConfigurationLoaderTest do
  use BorutaAdmin.DataCase

  alias Boruta.Ecto.Client
  alias Boruta.Ecto.Scope
  alias BorutaAdmin.ConfigurationLoader
  alias BorutaGateway.Certificate
  alias BorutaGateway.ServiceRegistry.Record
  alias BorutaGateway.Upstreams.Upstream
  alias BorutaIdentity.Accounts.Role
  alias BorutaIdentity.Configuration.ErrorTemplate
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Organizations.Organization

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

  test "returns an error with a bad organization configuration file" do
    assert BorutaIdentity.Repo.all(Backend) |> Enum.count() == 1

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_organization_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                organization: ["Schema does not allow additional properties: #/additional."]
              }}
  end

  test "returns an error with a bad identity provider configuration file" do
    identity_provider_count = BorutaIdentity.Repo.aggregate(IdentityProvider, :count)

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/bad_identity_provider_configuration.yml")

    assert ConfigurationLoader.from_file!(configuration_file_path) ==
             {:ok,
              %{
                identity_provider: ["Schema does not allow additional properties: #/additional."]
              }}

    assert BorutaIdentity.Repo.aggregate(IdentityProvider, :count) == identity_provider_count
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

  test "loads a cluster CA" do
    root_ca = Certificate.generate_root_ca_pem!()
    paths = Certificate.paths()

    File.write!(paths.root_ca_certificate, "stale certificate")
    File.write!(paths.root_ca_private_key, "stale private key")

    assert %{cluster_ca: []} =
             ConfigurationLoader.load_configuration(%{
               "cluster_ca" => %{
                 "certificate" => root_ca.certificate,
                 "private_key" => root_ca.private_key
               }
             })

    assert %Record{
             node_name: "__cluster_ca__",
             ip_address: "__cluster_ca__",
             certificate: certificate,
             private_key: private_key,
             status: "root"
           } = BorutaGateway.Repo.get_by(Record, node_name: "__cluster_ca__")

    assert certificate == root_ca.certificate
    assert private_key == root_ca.private_key
    assert File.read!(paths.root_ca_certificate) == root_ca.certificate
    assert File.read!(paths.root_ca_private_key) == root_ca.private_key

    assert %{cluster_ca: ["Invalid cluster CA certificate/private_key pair."]} =
             ConfigurationLoader.load_configuration(%{
               "cluster_ca" => %{
                 "certificate" => root_ca.certificate,
                 "private_key" => "invalid"
               }
             })
  end

  test "loads a file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    Application.delete_env(ConfigurationLoader, :node_name)

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/test/configuration_files/full_configuration.yml")

    ConfigurationLoader.from_file!(configuration_file_path)

    assert ConfigurationLoader.aliases() == [
             "full-configuration.local",
             "full-configuration.internal",
             node_hostname()
           ]

    assert [
             %Upstream{
               scheme: "http",
               host: "httpbin.patatoid.fr",
               port: 80,
               uris: ["/httpbin"],
               required_scopes: %{"GET" => ["test"]},
               strip_uri: true,
               authorize: true,
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
               error_content_type: "test",
               forbidden_response: "test",
               unauthorized_response: "test",
               forwarded_token_signature_alg: "HS384",
               forwarded_token_secret: "test",
               forwarded_token_public_key: nil,
               forwarded_token_private_key: nil
             }
           ] = BorutaGateway.Repo.all(Upstream)

    assert %Backend{
             name: "test",
             verifiable_credentials: [
               %{
                 "credential_identifier" => "TestCredential",
                 "scopes" => ["test"]
               }
             ]
           } = BorutaIdentity.Repo.get_by(Backend, name: "test")

    assert %IdentityProvider{
             name: "test",
             templates: [%Template{content: "test", type: "layout"}]
           } =
             BorutaIdentity.Repo.get_by(IdentityProvider, name: "test")
             |> BorutaIdentity.Repo.preload(:templates)

    assert %Client{
             name: "test",
             public_client_id: "https://test.client",
             check_public_client_id: true,
             secret: "secret",
             confidential: true,
             redirect_uris: ["https://test.client/callback"],
             authorized_resources: ["https://resource.test"],
             supported_grant_types: ["client_credentials", "authorization_code"],
             authorize_scope: true,
             enforce_dpop: true,
             enforce_tx_code: true,
             access_token_ttl: 10,
             agent_token_ttl: 10,
             authorization_code_ttl: 10,
             authorization_request_ttl: 10,
             refresh_token_ttl: 10,
             id_token_ttl: 10,
             pkce: true,
             public_refresh_token: true,
             public_revoke: true,
             id_token_signature_alg: "HS256",
             token_endpoint_auth_methods: ["client_secret_basic"],
             token_endpoint_jwt_auth_alg: "HS256",
             userinfo_signed_response_alg: "HS256",
             jwt_public_key: "public-key",
             jwks_uri: "https://test.client/.well-known/jwks.json",
             id_token_kid: "test-kid",
             logo_uri: "https://test.client/logo.png",
             metadata: %{"custom" => "value"},
             response_mode: "post",
             signatures_adapter: "Elixir.Boruta.Internal.Signatures",
             key_pair_type: %{
               "type" => "rsa",
               "modulus_size" => "2048",
               "exponent_size" => "65537"
             }
           } = BorutaAuth.Repo.all(Client) |> List.last()

    assert %Scope{name: "test"} = BorutaAuth.Repo.all(Scope) |> List.last()

    assert %Role{name: "test"} = BorutaIdentity.Repo.all(Role) |> List.last()

    assert %Organization{name: "test"} = BorutaIdentity.Repo.all(Organization) |> List.last()

    assert %ErrorTemplate{type: "500", content: "test"} =
             BorutaIdentity.Repo.all(ErrorTemplate) |> List.last()

    counts = configuration_counts()

    assert {:ok,
            %{
              backend: [],
              client: [],
              error_template: [],
              gateway: [],
              identity_provider: [],
              microgateway: [],
              organization: [],
              role: [],
              scope: []
            }} = ConfigurationLoader.from_file!(configuration_file_path)

    assert configuration_counts() == counts
  end

  test "loads example file" do
    assert BorutaGateway.Repo.all(Upstream) |> Enum.empty?()

    Application.delete_env(ConfigurationLoader, :node_name)

    configuration_file_path =
      :code.priv_dir(:boruta_admin)
      |> Path.join("/examples/configuration.yml")

    assert {:ok,
            %{
              client: [
                %Ecto.Changeset{
                  errors: [
                    redirect_uris: {"`{{PREAUTHORIZED_CODE_REDIRECT_URI}}` is invalid", []},
                    redirect_uris: {"`{{PRESENTATION_REDIRECT_URI}}` is invalid", []}
                  ]
                }
              ]
            }} = ConfigurationLoader.from_file!(configuration_file_path)

    assert %Backend{
             name: "Example backend",
             id: "00000000-0000-0000-0000-000000000001",
             verifiable_credentials: [
               %{
                 "claims" => [
                   %{
                     "label" => "boruta username",
                     "name" => "boruta_username",
                     "pointer" => "email",
                     "type" => "attribute"
                   }
                 ],
                 "credential_identifier" => "BorutaCredential",
                 "display" => %{
                   "background_color" => "#ffd758",
                   "logo" => %{
                     "alt_text" => "malachit logo",
                     "url" => "https://io.malach.it/assets/images/logo.png"
                   },
                   "name" => "Boruta username (JWT VC)",
                   "text_color" => "#333333"
                 },
                 "format" => "jwt_vc",
                 "types" => "VerifiableCredential BorutaCredentialJwtVc",
                 "version" => "13"
               }
             ],
             verifiable_presentations: [
               %{
                 "presentation_definition" =>
                   "{\n  \"id\": \"credential\",\n  \"input_descriptors\": [\n    {\n      \"id\": \"boruta_username\",\n      \"format\": {\n        \"jwt_vc\": {}\n      },\n      \"constraints\": {\n        \"fields\": [\n          {\n            \"path\": [ \"$.boruta_username\" ],\n            \"id\": \"Boruta account information\",\n            \"purpose\": \"Present account information to obtain access or further credentials\"\n          }\n        ]\n      }\n    }\n  ]\n}\n",
                 "presentation_identifier" => "BorutaCredentialJwtVc"
               }
             ]
           } = BorutaIdentity.Repo.all(Backend) |> List.last()

    assert %IdentityProvider{
             id: "00000000-0000-0000-0000-000000000001",
             backend_id: "00000000-0000-0000-0000-000000000001",
             name: "Example identity provider",
             consentable: true,
             choose_session: true,
             registrable: true
           } =
             BorutaIdentity.Repo.get(
               IdentityProvider,
               "00000000-0000-0000-0000-000000000001"
             )
             |> BorutaIdentity.Repo.preload(:templates)

    assert %Scope{
             name: "BorutaCredentialJwtVc",
             label: "boruta username",
             public: true
           } = BorutaAuth.Repo.all(Scope) |> List.last()
  end

  defp node_hostname do
    node()
    |> Atom.to_string()
    |> String.split("@", parts: 2)
    |> case do
      [_name, host] -> host
      [_name] -> :inet.gethostname() |> elem(1) |> to_string()
    end
  end

  defp configuration_counts do
    %{
      upstreams: BorutaGateway.Repo.aggregate(Upstream, :count),
      backends: BorutaIdentity.Repo.aggregate(Backend, :count),
      identity_providers: BorutaIdentity.Repo.aggregate(IdentityProvider, :count),
      clients: BorutaAuth.Repo.aggregate(Client, :count),
      scopes: BorutaAuth.Repo.aggregate(Scope, :count),
      roles: BorutaIdentity.Repo.aggregate(Role, :count),
      organizations: BorutaIdentity.Repo.aggregate(Organization, :count),
      error_templates: BorutaIdentity.Repo.aggregate(ErrorTemplate, :count)
    }
  end
end
