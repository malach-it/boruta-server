defmodule BorutaGateway.ConfigurationLoaderTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.Repo
  alias BorutaGateway.Upstreams.Upstream

  setup do
    Repo.delete_all(Upstream)

    :ok
  end

  test "returns an error with a bad configuration file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_configuration.yml")

    assert_raise MatchError, fn ->
      ConfigurationLoader.from_file!(configuration_file_path)
    end
  end

  test "returns an error with a bad gateway configuration file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_gateway_configuration.yml")

    assert_raise RuntimeError,
                 ~s|[{"Required properties scheme, host, port, uris were not present.", "#"}]|,
                 fn ->
                   ConfigurationLoader.from_file!(configuration_file_path)
                 end
  end

  test "returns an error with a bad microgateway configuration file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
      |> Path.join("/test/configuration_files/bad_microgateway_configuration.yml")

    assert_raise RuntimeError,
                 ~s|[{"Required properties scheme, host, port, uris were not present.", "#"}]|,
                 fn ->
                   ConfigurationLoader.from_file!(configuration_file_path)
                 end
  end

  test "loads a file" do
    assert Repo.all(Upstream) |> Enum.empty?()

    Application.delete_env(ConfigurationLoader, :node_name)

    configuration_file_path =
      :code.priv_dir(:boruta_gateway)
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
               node_name: "full-configuration",
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
           ] = Repo.all(Upstream)
  end

  test "adds the node hostname to aliases by default" do
    previous_aliases = Application.get_env(ConfigurationLoader, :aliases)
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    assert ConfigurationLoader.aliases() == ["service.local", node_hostname()]

    restore_env(:aliases, previous_aliases)
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

  defp restore_env(key, nil), do: Application.delete_env(ConfigurationLoader, key)
  defp restore_env(key, value), do: Application.put_env(ConfigurationLoader, key, value)
end
