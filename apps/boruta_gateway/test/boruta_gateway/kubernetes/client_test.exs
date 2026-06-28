defmodule BorutaGateway.Kubernetes.ClientTest do
  use ExUnit.Case

  alias BorutaGateway.Certificate
  alias BorutaGateway.Kubernetes.Client

  test "verifies the API server certificate with a configured server name" do
    root_ca = Certificate.generate_root_ca_pem!()
    Certificate.ensure!(root_ca)

    ca_cert_path = Path.join(System.tmp_dir!(), "kubernetes-client-ca-#{unique_id()}.crt")
    File.write!(ca_cert_path, root_ca.certificate)

    on_exit(fn -> File.rm(ca_cert_path) end)

    {:ok, listener} = ssl_listen()
    {:ok, {_address, port}} = :ssl.sockname(listener)

    parent = self()

    server =
      spawn_link(fn ->
        {:ok, socket} = :ssl.transport_accept(listener)
        {:ok, socket} = :ssl.handshake(socket)
        {:ok, request} = :ssl.recv(socket, 0, 5_000)

        send(parent, {:request, request})

        :ok =
          :ssl.send(
            socket,
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 12\r\n\r\n{\"items\":[]}"
          )

        :ssl.close(socket)
        :ssl.close(listener)
      end)

    on_exit(fn ->
      if Process.alive?(server), do: Process.exit(server, :normal)
    end)

    assert {:ok, %{"items" => []}} =
             Client.list_services(
               host: "127.0.0.1",
               port: Integer.to_string(port),
               token: "service-account-token",
               ca_cert_path: ca_cert_path,
               server_name: "localhost"
             )

    assert_receive {:request, request}, 1_000
    assert request =~ "GET /api/v1/services HTTP/1.1"
    assert String.downcase(request) =~ "authorization: bearer service-account-token"
  end

  defp ssl_listen do
    :ssl.listen(
      0,
      [:binary, {:packet, :raw}, {:active, false}, {:reuseaddr, true}] ++
        Certificate.ssl_options()
    )
  end

  defp unique_id do
    System.unique_integer([:positive, :monotonic])
  end
end
