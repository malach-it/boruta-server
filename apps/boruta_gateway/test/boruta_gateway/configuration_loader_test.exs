defmodule BorutaGateway.ConfigurationLoaderTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams.Upstream

  test "returns an error with a bad configuration file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_configuration.yml")

    assert_raise MatchError, fn ->
      ConfigurationLoader.from_file!(configuration_file_path)
    end
  end

  test "loads a file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
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
             }
           ] = Repo.all(Upstream)
  end
end
