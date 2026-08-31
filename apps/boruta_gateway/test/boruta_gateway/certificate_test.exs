defmodule BorutaGateway.CertificateTest do
  use ExUnit.Case

  alias BorutaGateway.Certificate

  setup do
    paths = Certificate.paths()
    certificate_directory = Path.dirname(paths.certificate)

    certificate_paths =
      Map.values(paths) ++
        [
          Path.join(certificate_directory, "cluster_ca.crt"),
          Path.join(certificate_directory, "cluster_ca.key")
        ]

    existing_files = Map.new(certificate_paths, &{&1, read_file(&1)})
    previous_config = Application.get_env(:boruta_gateway, Certificate)

    on_exit(fn ->
      Enum.each(existing_files, fn
        {path, {:ok, content}} -> File.write!(path, content)
        {path, :error} -> File.rm(path)
      end)

      case previous_config do
        nil -> Application.delete_env(:boruta_gateway, Certificate)
        config -> Application.put_env(:boruta_gateway, Certificate, config)
      end
    end)

    :ok
  end

  test "generated certificates are signed by the current root CA key" do
    root_ca = Certificate.generate_root_ca_pem!()
    regenerate_certificate!(root_ca)
    certificate = Certificate.pem()

    assert signed_by?(Certificate.paths().certificate, root_ca.certificate)

    new_root_ca = Certificate.generate_root_ca_pem!()
    Certificate.ensure!(new_root_ca)

    refute Certificate.pem() == certificate
    assert signed_by?(Certificate.paths().certificate, new_root_ca.certificate)
    refute signed_by?(Certificate.paths().certificate, root_ca.certificate)
  end

  test "does not generate a self-signed gateway certificate without a root CA" do
    paths = Certificate.paths()
    File.rm(paths.certificate)
    File.rm(paths.private_key)

    assert_raise ArgumentError,
                 "cluster root CA is required to generate a gateway certificate",
                 fn -> Certificate.ensure!() end

    refute File.exists?(paths.certificate)
    refute File.exists?(paths.private_key)
  end

  test "does not persist the cluster root CA on the gateway filesystem" do
    paths = Certificate.paths()
    certificate_directory = Path.dirname(paths.certificate)
    root_ca_certificate_path = Path.join(certificate_directory, "cluster_ca.crt")
    root_ca_private_key_path = Path.join(certificate_directory, "cluster_ca.key")
    File.rm(root_ca_certificate_path)
    File.rm(root_ca_private_key_path)

    root_ca = Certificate.generate_root_ca_pem!()
    regenerate_certificate!(root_ca)

    refute File.exists?(root_ca_certificate_path)
    refute File.exists?(root_ca_private_key_path)
  end

  defp regenerate_certificate!(root_ca) do
    paths = Certificate.paths()

    File.rm(paths.certificate)
    File.rm(paths.private_key)
    Certificate.ensure!(root_ca)
  end

  defp signed_by?(certificate_path, root_ca_certificate) do
    root_ca_path =
      Path.join(System.tmp_dir!(), "boruta_root_ca_#{System.unique_integer([:positive])}.crt")

    try do
      File.write!(root_ca_path, root_ca_certificate)

      match?(
        {_output, 0},
        System.cmd("openssl", ["verify", "-CAfile", root_ca_path, certificate_path],
          stderr_to_stdout: true
        )
      )
    after
      File.rm(root_ca_path)
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, _reason} -> :error
    end
  end
end
