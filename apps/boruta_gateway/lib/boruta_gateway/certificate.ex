defmodule BorutaGateway.Certificate do
  @moduledoc false

  alias BorutaGateway.ConfigurationLoader

  @certificate_file "gateway.crt"
  @private_key_file "gateway.key"
  @root_ca_certificate_file "cluster_ca.crt"
  @root_ca_private_key_file "cluster_ca.key"
  @trusted_certificates_file "service_registry_cacerts.pem"

  def ensure!(root_ca \\ nil) do
    directory = directory()
    certificate_path = Path.join(directory, @certificate_file)
    private_key_path = Path.join(directory, @private_key_file)

    File.mkdir_p!(directory)

    generate!(certificate_path, private_key_path, root_ca)
  end

  def generate_root_ca_pem! do
    directory = directory()
    suffix = unique_suffix()
    certificate_path = Path.join(directory, "cluster_ca_#{suffix}.crt")
    private_key_path = Path.join(directory, "cluster_ca_#{suffix}.key")

    File.mkdir_p!(directory)
    generate_root_ca!(certificate_path, private_key_path)

    root_ca = %{
      certificate: File.read!(certificate_path),
      private_key: File.read!(private_key_path)
    }

    write_root_ca!(root_ca)

    File.rm(certificate_path)
    File.rm(private_key_path)

    root_ca
  end

  def root_ca_valid?(%{certificate: certificate, private_key: private_key})
      when is_binary(certificate) and is_binary(private_key) do
    directory = directory()
    suffix = unique_suffix()
    certificate_path = Path.join(directory, "cluster_ca_validation_#{suffix}.crt")
    private_key_path = Path.join(directory, "cluster_ca_validation_#{suffix}.key")

    File.mkdir_p!(directory)
    File.write!(certificate_path, certificate)
    File.write!(private_key_path, private_key)

    certificate_modulus =
      System.cmd("openssl", ["x509", "-noout", "-modulus", "-in", certificate_path],
        stderr_to_stdout: true
      )

    private_key_modulus =
      System.cmd("openssl", ["rsa", "-noout", "-modulus", "-in", private_key_path],
        stderr_to_stdout: true
      )

    File.rm(certificate_path)
    File.rm(private_key_path)

    case {certificate_modulus, private_key_modulus} do
      {{certificate_output, 0}, {private_key_output, 0}} ->
        normalize_modulus(certificate_output) == normalize_modulus(private_key_output)

      _result ->
        false
    end
  rescue
    _error -> false
  end

  def root_ca_valid?(_root_ca), do: false

  defp normalize_modulus(output) do
    output
    |> String.split("\n")
    |> Enum.find(&String.starts_with?(&1, "Modulus="))
  end

  def ssl_options do
    case Application.get_env(:boruta_gateway, __MODULE__, [])[:ssl_options] do
      nil ->
        ensure!()
        Application.fetch_env!(:boruta_gateway, __MODULE__)[:ssl_options]

      ssl_options ->
        ssl_options
    end
  end

  def paths do
    directory = directory()

    %{
      certificate: Path.join(directory, @certificate_file),
      private_key: Path.join(directory, @private_key_file),
      root_ca_certificate: Path.join(directory, @root_ca_certificate_file),
      root_ca_private_key: Path.join(directory, @root_ca_private_key_file),
      trusted_certificates: Path.join(directory, @trusted_certificates_file)
    }
  end

  def pem do
    ssl_options()

    paths()
    |> Map.fetch!(:certificate)
    |> File.read!()
  end

  def load_trusted_certificates!(certificates) do
    system_cacerts()

    certificates =
      certificates
      |> Enum.flat_map(&decode_certificates/1)
      |> Enum.uniq()

    trusted_certificates_path = paths().trusted_certificates

    trusted_certificates =
      certificates
      |> Enum.map(&{:Certificate, &1, :not_encrypted})
      |> :public_key.pem_encode()

    trusted_certificates_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(trusted_certificates_path, trusted_certificates)

    :ok = :public_key.cacerts_load(trusted_certificates_path)
  end

  def cacerts do
    :public_key.cacerts_get()
    |> Enum.flat_map(&normalize_cacert/1)
  end

  def gateway_cacerts do
    (system_cacerts() ++ cacerts())
    |> Enum.uniq()
  end

  defp directory do
    :boruta_gateway
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("ssl")
  end

  defp unique_suffix do
    System.unique_integer([:positive, :monotonic])
  end

  defp generate!(certificate_path, private_key_path, nil) do
    args = [
      "req",
      "-x509",
      "-newkey",
      "rsa:2048",
      "-sha256",
      "-days",
      "3650",
      "-nodes",
      "-subj",
      "/CN=#{ConfigurationLoader.node_name()}",
      "-addext",
      "basicConstraints=critical,CA:FALSE",
      "-addext",
      "keyUsage=critical,digitalSignature,keyEncipherment",
      "-addext",
      "extendedKeyUsage=serverAuth,clientAuth",
      "-addext",
      "subjectAltName=#{subject_alt_names()}",
      "-keyout",
      private_key_path,
      "-out",
      certificate_path
    ]

    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {_output, 0} ->
        File.chmod(private_key_path, 0o600)
        cache_ssl_options!(certificate_path, private_key_path)
        :ok

      {output, status} ->
        raise "openssl certificate generation failed with status #{status}: #{String.trim(output)}"
    end
  rescue
    error in ErlangError ->
      reraise RuntimeError,
              [message: "openssl certificate generation failed: #{inspect(error.original)}"],
              __STACKTRACE__
  end

  defp generate!(certificate_path, private_key_path, %{
         certificate: root_ca_certificate,
         private_key: root_ca_private_key
       }) do
    write_root_ca!(%{
      certificate: root_ca_certificate,
      private_key: root_ca_private_key
    })

    directory = directory()
    suffix = unique_suffix()
    root_ca_certificate_path = Path.join(directory, "cluster_ca_sign_#{suffix}.crt")
    root_ca_private_key_path = Path.join(directory, "cluster_ca_sign_#{suffix}.key")
    certificate_request_path = Path.join(directory, "gateway_#{suffix}.csr")
    certificate_extensions_path = Path.join(directory, "gateway_#{suffix}.ext")

    File.write!(root_ca_certificate_path, root_ca_certificate)
    File.write!(root_ca_private_key_path, root_ca_private_key)
    File.chmod(root_ca_private_key_path, 0o600)

    File.write!(certificate_extensions_path, certificate_extensions())

    request_args = [
      "req",
      "-newkey",
      "rsa:2048",
      "-sha256",
      "-nodes",
      "-subj",
      "/CN=#{ConfigurationLoader.node_name()}",
      "-keyout",
      private_key_path,
      "-out",
      certificate_request_path
    ]

    sign_args = [
      "x509",
      "-req",
      "-sha256",
      "-days",
      "3650",
      "-in",
      certificate_request_path,
      "-CA",
      root_ca_certificate_path,
      "-CAkey",
      root_ca_private_key_path,
      "-CAcreateserial",
      "-out",
      certificate_path,
      "-extfile",
      certificate_extensions_path
    ]

    with {_output, 0} <- System.cmd("openssl", request_args, stderr_to_stdout: true),
         {_output, 0} <- System.cmd("openssl", sign_args, stderr_to_stdout: true) do
      File.chmod(private_key_path, 0o600)
      File.rm(root_ca_certificate_path)
      File.rm(root_ca_private_key_path)
      File.rm(certificate_request_path)
      File.rm(certificate_extensions_path)
      File.rm("#{root_ca_certificate_path}.srl")
      cache_ssl_options!(certificate_path, private_key_path)
      :ok
    else
      {output, status} ->
        raise "openssl certificate generation failed with status #{status}: #{String.trim(output)}"
    end
  rescue
    error in ErlangError ->
      reraise RuntimeError,
              [message: "openssl certificate generation failed: #{inspect(error.original)}"],
              __STACKTRACE__
  end

  defp generate_root_ca!(certificate_path, private_key_path) do
    args = [
      "req",
      "-x509",
      "-newkey",
      "rsa:4096",
      "-sha256",
      "-days",
      "3650",
      "-nodes",
      "-subj",
      "/CN=Boruta Service Registry Root CA",
      "-addext",
      "basicConstraints=critical,CA:TRUE,pathlen:0",
      "-addext",
      "keyUsage=critical,keyCertSign,cRLSign",
      "-keyout",
      private_key_path,
      "-out",
      certificate_path
    ]

    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {_output, 0} ->
        File.chmod(private_key_path, 0o600)
        :ok

      {output, status} ->
        raise "openssl root CA generation failed with status #{status}: #{String.trim(output)}"
    end
  rescue
    error in ErlangError ->
      reraise RuntimeError,
              [message: "openssl root CA generation failed: #{inspect(error.original)}"],
              __STACKTRACE__
  end

  defp cache_ssl_options!(certificate_path, private_key_path) do
    ssl_options = [
      {:cert, decode_certificate!(certificate_path)},
      {:key, decode_private_key!(private_key_path)}
    ]

    :boruta_gateway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.put(:ssl_options, ssl_options)
    |> then(&Application.put_env(:boruta_gateway, __MODULE__, &1))
  end

  defp decode_certificate!(certificate_path) do
    certificate_path
    |> File.read!()
    |> :public_key.pem_decode()
    |> Enum.find(fn
      {:Certificate, _der, _encoding} -> true
      _entry -> false
    end)
    |> case do
      {:Certificate, der, _encoding} -> der
      _entry -> raise "certificate file does not contain a PEM certificate: #{certificate_path}"
    end
  end

  defp decode_certificates(nil), do: []
  defp decode_certificates(""), do: []

  defp decode_certificates(certificate) when is_binary(certificate) do
    certificate
    |> :public_key.pem_decode()
    |> Enum.flat_map(fn
      {:Certificate, der, _encoding} -> [der]
      _entry -> []
    end)
  rescue
    _error -> []
  end

  def write_root_ca!(%{certificate: certificate, private_key: private_key}) do
    paths = paths()

    paths.root_ca_certificate
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(paths.root_ca_certificate, certificate)
    File.write!(paths.root_ca_private_key, private_key)
    File.chmod(paths.root_ca_private_key, 0o600)
  end

  defp system_cacerts do
    case Application.get_env(:boruta_gateway, __MODULE__, [])[:system_cacerts] do
      nil ->
        cacerts =
          cacerts()

        :boruta_gateway
        |> Application.get_env(__MODULE__, [])
        |> Keyword.put(:system_cacerts, cacerts)
        |> then(&Application.put_env(:boruta_gateway, __MODULE__, &1))

        cacerts

      cacerts ->
        cacerts
    end
  end

  defp normalize_cacert({:cert, der, _decoded}), do: [der]
  defp normalize_cacert(der) when is_binary(der), do: [der]
  defp normalize_cacert(_cacert), do: []

  defp decode_private_key!(private_key_path) do
    private_key_path
    |> File.read!()
    |> :public_key.pem_decode()
    |> Enum.find(fn
      {:Certificate, _der, _encoding} -> false
      _entry -> true
    end)
    |> case do
      {key_type, der, :not_encrypted} ->
        {key_type, der}

      {key_type, der, encryption_info} ->
        {key_type, der, encryption_info}

      _entry ->
        raise "private key file does not contain a PEM private key: #{private_key_path}"
    end
  end

  defp subject_alt_names do
    dns_alt_names =
      [ConfigurationLoader.node_name(), "localhost" | ConfigurationLoader.aliases()]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.map(&"DNS:#{&1}")

    ip_alt_names =
      host_ips()
      |> Enum.map(&"IP:#{&1}")

    (dns_alt_names ++ ip_alt_names)
    |> Enum.uniq()
    |> Enum.join(",")
  end

  defp certificate_extensions do
    """
    basicConstraints=critical,CA:FALSE
    keyUsage=critical,digitalSignature,keyEncipherment
    extendedKeyUsage=serverAuth,clientAuth
    subjectAltName=#{subject_alt_names()}
    """
  end

  defp host_ips do
    case :inet.getifaddrs() do
      {:ok, interfaces} ->
        interfaces
        |> Enum.flat_map(fn {_name, options} -> Keyword.get_values(options, :addr) end)
        |> Enum.reject(&loopback?/1)
        |> Enum.map(&:inet.ntoa/1)
        |> Enum.map(&to_string/1)
        |> case do
          [] -> ["127.0.0.1"]
          addresses -> addresses
        end

      {:error, _reason} ->
        ["127.0.0.1"]
    end
  end

  defp loopback?({127, _, _, _}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback?(_address), do: false
end
