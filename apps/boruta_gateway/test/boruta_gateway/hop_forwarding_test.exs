defmodule BorutaGateway.HopForwardingTest do
  use ExUnit.Case, async: false

  alias BorutaGateway.{Certificate, HopState, HttpGateway, HttpProxy, HttpsGateway}
  alias BorutaGateway.Upstreams.Upstream

  for {gateway, transport} <- [{HttpGateway, :gen_tcp}, {HttpsGateway, :ssl}] do
    @gateway gateway
    @transport transport

    test "#{gateway} forwards hop IDs and rejects a request returning to this node" do
      {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false])
      {:ok, {_, upstream_port}} = :inet.sockname(listener)
      on_exit(fn -> :gen_tcp.close(listener) end)

      upstream = %Upstream{
        id: "hop-test",
        scheme: "http",
        host: "localhost",
        port: upstream_port,
        uris: ["/"],
        authorize: false,
        mtls_enabled: false
      }

      {server, port} = start_gateway(@gateway, upstream)
      on_exit(fn -> if Process.alive?(server), do: GenServer.stop(server) end)
      {:ok, socket} = connect(@transport, port)
      :ok = @transport.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
      assert {:ok, forwarded_socket} = :gen_tcp.accept(listener, 1_000)
      assert {:ok, forwarded} = :gen_tcp.recv(forwarded_socket, 0, 1_000)

      assert forwarded =~
               "X-Hop-State: #{HopState.current() |> :binary.encode_unsigned() |> Base.encode64()}\r\n"

      :gen_tcp.close(forwarded_socket)
      @transport.close(socket)

      {:ok, socket} = connect(@transport, port)
      :ok = @transport.send(socket, forwarded)
      assert {:ok, response} = @transport.recv(socket, 0, 1_000)
      assert response =~ "HTTP/1.1 418 I'm a teapot\r\n"
      assert String.ends_with?(response, "I'm a teapot")
      assert {:error, :timeout} = :gen_tcp.accept(listener, 100)
      @transport.close(socket)
    end
  end

  test "uses the current instance public key's SHA-256 fingerprint directly" do
    der = Certificate.ssl_options() |> Keyword.fetch!(:cert)
    {:Certificate, tbs, _, _} = :public_key.pkix_decode_cert(der, :plain)
    public_key_info = elem(tbs, 7)
    digest = :crypto.hash(:sha256, :public_key.der_encode(:SubjectPublicKeyInfo, public_key_info))
    assert HopState.current() == :binary.decode_unsigned(digest)
  end

  test "the forward proxy rejects a repeated node before connecting upstream" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_, port}} = :inet.sockname(listener)
    {:ok, proxy} = HttpProxy.start_link(listen_socket: listener, downstream_transport: :tcp)
    Process.unlink(proxy)

    on_exit(fn ->
      if Process.alive?(proxy), do: Process.exit(proxy, :kill)
      :gen_tcp.close(listener)
    end)

    {:ok, socket} = connect(:gen_tcp, port)

    request =
      "GET http://localhost:1/ HTTP/1.1\r\nHost: localhost\r\nX-Hop-State: #{HopState.current() |> :binary.encode_unsigned() |> Base.encode64()}\r\n\r\n"

    :ok = :gen_tcp.send(socket, request)
    assert {:ok, response} = :gen_tcp.recv(socket, 0, 1_000)
    assert response =~ "HTTP/1.1 418 I'm a teapot\r\n"
    :gen_tcp.close(socket)
  end

  defp start_gateway(gateway, upstream) do
    {:ok, spare} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_, port}} = :inet.sockname(spare)
    :gen_tcp.close(spare)

    options = [port: port, num_acceptors: 1, match_function: fn _, _ -> upstream end]

    options =
      if gateway == HttpsGateway,
        do: options ++ [ssl_options: Certificate.ssl_options()],
        else: options

    {:ok, server} = Module.concat(gateway, Server).start(options)
    Process.unlink(server)
    {server, port}
  end

  defp connect(:gen_tcp, port),
    do: :gen_tcp.connect(~c"localhost", port, [:binary, active: false], 1_000)

  defp connect(:ssl, port),
    do: :ssl.connect(~c"localhost", port, [:binary, active: false, verify: :verify_none], 1_000)
end
