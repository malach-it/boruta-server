defmodule BorutaGateway.CertificateChainTest do
  use ExUnit.Case, async: false
  alias BorutaGateway.Certificate

  setup do
    directory = Path.join(System.tmp_dir!(), "boruta-chain-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    File.chmod!(directory, 0o700)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{directory: directory}
  end

  test "serves intermediates so a root-only client can validate TLS", %{directory: dir} do
    openssl(
      dir,
      ~w(req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=TestRoot -keyout root.key -out root.pem -addext basicConstraints=critical,CA:TRUE)
    )

    openssl(
      dir,
      ~w(req -new -newkey rsa:2048 -nodes -subj /CN=TestIntermediate -keyout intermediate.key -out intermediate.csr)
    )

    File.write!(
      Path.join(dir, "ca.ext"),
      "basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n"
    )

    openssl(
      dir,
      ~w(x509 -req -in intermediate.csr -CA root.pem -CAkey root.key -CAcreateserial -days 1 -extfile ca.ext -out intermediate.pem)
    )

    openssl(
      dir,
      ~w(req -new -newkey rsa:2048 -nodes -subj /CN=localhost -keyout leaf.key -out leaf.csr)
    )

    File.write!(
      Path.join(dir, "leaf.ext"),
      "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost\n"
    )

    openssl(
      dir,
      ~w(x509 -req -in leaf.csr -CA intermediate.pem -CAkey intermediate.key -CAcreateserial -days 1 -extfile leaf.ext -out leaf.pem)
    )

    chain_path = Path.join(dir, "fullchain.pem")

    File.write!(
      chain_path,
      File.read!(Path.join(dir, "leaf.pem")) <> File.read!(Path.join(dir, "intermediate.pem"))
    )

    options = Certificate.ssl_options(chain_path, Path.join(dir, "leaf.key"))
    assert [leaf, intermediate] = options[:cert]
    assert leaf == der(dir, "leaf.pem")
    assert intermediate == der(dir, "intermediate.pem")
    refute Keyword.has_key?(options, :cacerts)

    assert is_binary(
             Certificate.ssl_options(Path.join(dir, "leaf.pem"), Path.join(dir, "leaf.key"))[
               :cert
             ]
           )

    {:ok, listener} = :ssl.listen(0, options ++ [active: false, reuseaddr: true])
    on_exit(fn -> :ssl.close(listener) end)
    {:ok, {_, port}} = :ssl.sockname(listener)

    server =
      Task.async(fn ->
        {:ok, socket} = :ssl.transport_accept(listener, 5_000)
        {:ok, socket} = :ssl.handshake(socket, 5_000)
        :ssl.send(socket, "chain verified")
        :ssl.close(socket)
      end)

    assert {:ok, client} =
             :ssl.connect(
               ~c"localhost",
               port,
               [
                 verify: :verify_peer,
                 cacerts: [der(dir, "root.pem")],
                 depth: 3,
                 server_name_indication: ~c"localhost",
                 active: false,
                 mode: :binary
               ],
               5_000
             )

    assert {:ok, "chain verified"} = :ssl.recv(client, 0, 5_000)
    :ssl.close(client)
    Task.await(server)
  end

  test "rejects a PEM file without certificates", %{directory: dir} do
    path = Path.join(dir, "empty.pem")
    File.write!(path, "")

    assert_raise RuntimeError, ~r/does not contain a PEM certificate/, fn ->
      Certificate.ssl_options(path, Path.join(dir, "unused.key"))
    end
  end

  defp openssl(dir, args) do
    {output, status} = System.cmd("openssl", args, cd: dir, stderr_to_stdout: true)
    assert status == 0, output
  end

  defp der(dir, name) do
    [{:Certificate, der, _}] = dir |> Path.join(name) |> File.read!() |> :public_key.pem_decode()
    der
  end
end
