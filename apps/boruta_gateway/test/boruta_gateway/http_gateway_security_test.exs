defmodule BorutaGateway.HttpGatewaySecurityTest do
  use ExUnit.Case

  alias BorutaGateway.HttpGateway
  alias BorutaGateway.PhiNoise
  alias BorutaGateway.Upstreams.Upstream

  @noise_openapi Jason.encode!(%{
                   "openapi" => "3.0.0",
                   "paths" => %{"/allowed" => %{"get" => %{}}}
                 })

  test "rejects a second request buffered behind an authorized request" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    upstream = upstream(upstream_port)

    {gateway, gateway_port} =
      start_gateway(fn _host, _path -> upstream end)

    {:ok, socket} = connect(gateway_port)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /allowed HTTP/1.1\r\nHost: gateway.test\r\n\r\n" <>
          "GET /protected HTTP/1.1\r\nHost: gateway.test\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 400 Bad Request" <> _rest} = :gen_tcp.recv(socket, 0, 1_000)
    assert {:error, :timeout} = :gen_tcp.accept(upstream_listener, 100)

    close_gateway(socket, gateway, upstream_listener)
  end

  test "does not treat authorization-looking request body bytes as headers" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    upstream = %{upstream(upstream_port) | authorize: true}

    {gateway, gateway_port} =
      start_gateway(fn _host, _path -> upstream end)

    body = "Authorization: Bearer body-token"
    {:ok, socket} = connect(gateway_port)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /protected HTTP/1.1\r\nHost: gateway.test\r\n" <>
          "Content-Length: #{byte_size(body)}\r\n\r\n#{body}"
      )

    assert {:ok, "HTTP/1.1 401 Unauthorized" <> _rest} = :gen_tcp.recv(socket, 0, 1_000)
    assert {:error, :timeout} = :gen_tcp.accept(upstream_listener, 100)

    close_gateway(socket, gateway, upstream_listener)
  end

  test "does not rewrite authorization-looking request body bytes" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)
    parent = self()

    upstream_process =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 1_000)
        send(parent, {:upstream_payload, payload})
        :gen_tcp.close(socket)
      end)

    upstream = upstream(upstream_port)

    {gateway, gateway_port} =
      start_gateway(fn _host, _path -> upstream end)

    body = "prefix\r\nAuthorization: body-value\r\nsuffix"
    {:ok, socket} = connect(gateway_port)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /allowed HTTP/1.1\r\nHost: gateway.test\r\n" <>
          "Content-Length: #{byte_size(body)}\r\n\r\n#{body}"
      )

    assert_receive {:upstream_payload, payload}, 1_000
    assert String.ends_with?(payload, body)

    close_gateway(socket, gateway, upstream_listener)
    Process.unlink(upstream_process)
  end

  test "never forwards bytes beyond the declared request body" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)
    parent = self()

    upstream_process =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, initial_payload} = :gen_tcp.recv(socket, 0, 1_000)
        send(parent, {:initial_payload, initial_payload})
        send(parent, {:trailing_payload, :gen_tcp.recv(socket, 0, 1_000)})
        :gen_tcp.close(socket)
      end)

    upstream = upstream(upstream_port)

    {gateway, gateway_port} =
      start_gateway(fn _host, _path -> upstream end)

    {:ok, socket} = connect(gateway_port)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /allowed HTTP/1.1\r\nHost: gateway.test\r\nContent-Length: 4\r\n\r\nab"
      )

    assert_receive {:initial_payload, initial_payload}, 1_000
    assert initial_payload =~ "\r\n\r\nab"

    :ok =
      :gen_tcp.send(
        socket,
        "cdGET /protected HTTP/1.1\r\nHost: gateway.test\r\n\r\n"
      )

    assert_receive {:trailing_payload, {:error, :closed}}, 1_000

    :gen_tcp.close(socket)
    Supervisor.stop(gateway)
    Process.unlink(upstream_process)
    :gen_tcp.close(upstream_listener)
  end

  test "idle connections release an acceptor" do
    {gateway, gateway_port} =
      start_gateway(fn _host, _path -> nil end, idle_timeout: 50)

    {:ok, idle_socket} = connect(gateway_port)
    assert {:error, :closed} = :gen_tcp.recv(idle_socket, 0, 500)

    {:ok, next_socket} = connect(gateway_port)
    :ok = :gen_tcp.send(next_socket, "GET / HTTP/1.1\r\nHost: gateway.test\r\n\r\n")
    assert {:ok, "HTTP/1.1 403 Forbidden" <> _rest} = :gen_tcp.recv(next_socket, 0, 1_000)

    :gen_tcp.close(idle_socket)
    :gen_tcp.close(next_socket)
    Supervisor.stop(gateway)
  end

  test "returns 403 Forbidden when noise cancelling rejects a request" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)
    {:ok, model} = PhiNoise.train(@noise_openapi)

    upstream = %{
      upstream(upstream_port)
      | noise_cancelling_enabled: true,
        noise_cancelling_model: PhiNoise.export(model)
    }

    {gateway, gateway_port} = start_gateway(fn _host, _path -> upstream end)
    {:ok, socket} = connect(gateway_port)

    :ok = :gen_tcp.send(socket, "GET /.env HTTP/1.1\r\nHost: gateway.test\r\n\r\n")

    assert {:ok, response} = :gen_tcp.recv(socket, 0, 1_000)
    assert response =~ "HTTP/1.1 403 Forbidden"
    assert response =~ "Content-Type: text/plain; charset=utf-8"
    assert response =~ "Content-Length: 43"
    assert response =~ "\r\n\r\nthe request has been rejected by the server"
    assert {:error, :timeout} = :gen_tcp.accept(upstream_listener, 100)

    close_gateway(socket, gateway, upstream_listener)
  end

  defp start_gateway(match_function, opts \\ []) do
    {:ok, port} = free_port()

    {:ok, gateway} =
      HttpGateway.Server.start(
        Keyword.merge(
          [port: port, num_acceptors: 1, match_function: match_function],
          opts
        )
      )

    {gateway, port}
  end

  defp upstream(port) do
    %Upstream{
      id: Ecto.UUID.generate(),
      scheme: "http",
      host: "127.0.0.1",
      port: port,
      uris: ["/"],
      authorize: false,
      strip_uri: false
    }
  end

  defp connect(port) do
    :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])
  end

  defp listen do
    :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
  end

  defp free_port do
    {:ok, socket} = listen()
    {:ok, {_address, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    {:ok, port}
  end

  defp close_gateway(socket, gateway, upstream_listener) do
    :gen_tcp.close(socket)
    Supervisor.stop(gateway)
    :gen_tcp.close(upstream_listener)
  end
end
