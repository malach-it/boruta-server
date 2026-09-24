defmodule BorutaGateway.UpstreamConnectionTest do
  use ExUnit.Case

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.HttpGateway
  alias BorutaGateway.HttpProxy
  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Record
  alias BorutaGateway.UpstreamConnection
  alias BorutaGateway.Upstreams.Upstream

  test "connects to an advertised cluster proxy through any registered alias" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)
    {:ok, proxy_port} = free_port()
    parent = self()

    upstream_process =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        send(parent, {:upstream_payload, payload})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.close(socket)
      end)

    proxy_url = "https://localhost:#{proxy_port}"

    record = %Record{
      id: Ecto.UUID.generate(),
      node_name: ConfigurationLoader.node_name(),
      ip_address: "127.0.0.1",
      aliases: ["unused.proxy.internal", "localhost"],
      status: "online",
      configuration: %{
        "services" => [
          %{
            "name" => "HTTPS proxy",
            "scheme" => "https",
            "enabled" => true,
            "port" => proxy_port
          }
        ]
      }
    }

    start_service_registry(%{"127.0.0.1" => record})
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)
    {:ok, gateway_port} = free_port()

    upstream = %Upstream{
      id: Ecto.UUID.generate(),
      scheme: "http",
      host: "localhost",
      port: upstream_port,
      proxy_url: proxy_url,
      uris: ["/"],
      authorize: false,
      strip_uri: false
    }

    {:ok, gateway} =
      HttpGateway.Server.start(
        port: gateway_port,
        num_acceptors: 1,
        match_function: fn _host, _path -> upstream end
      )

    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", gateway_port, [:binary, active: false])

    :ok = :gen_tcp.send(socket, "GET /proxied HTTP/1.1\r\nHost: gateway.test\r\n\r\n")

    assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
             :gen_tcp.recv(socket, 0, 5_000)

    assert_receive {:upstream_payload, upstream_payload}, 1_000
    assert upstream_payload =~ "GET /proxied HTTP/1.1\r\n"

    :gen_tcp.close(socket)
    Supervisor.stop(gateway)
    Supervisor.stop(proxy)
    :gen_tcp.close(upstream_listener)
    Process.unlink(upstream_process)
  end

  test "uses absolute-form request targets when routing through a proxy" do
    upstream = %Upstream{scheme: "https", host: "upstream.example", port: 9443}
    payload = "GET /widgets?limit=10 HTTP/1.1\r\nHost: upstream.example\r\n\r\n"

    assert UpstreamConnection.prepare_request(payload, upstream, :proxy) ==
             "GET https://upstream.example:9443/widgets?limit=10 HTTP/1.1\r\n" <>
               "Host: upstream.example\r\n\r\n"
  end

  test "connects to an external proxy URL when it is not advertised by the cluster" do
    start_service_registry(%{})
    {:ok, closed_port} = free_port()

    upstream = %Upstream{
      scheme: "http",
      host: "upstream.example",
      port: 8080,
      proxy_url: "https://127.0.0.1:#{closed_port}"
    }

    assert {:error, :econnrefused} = UpstreamConnection.connect(upstream)
  end

  test "presents the gateway client certificate to an external proxy" do
    start_service_registry(%{})
    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    upstream = %Upstream{
      scheme: "http",
      host: "upstream.example",
      port: 8080,
      proxy_url: "https://localhost:#{proxy_port}"
    }

    assert {:ok, socket, :ssl, :proxy} = UpstreamConnection.connect(upstream)

    :ssl.close(socket)
    Supervisor.stop(proxy)
  end

  test "keeps direct request targets unchanged" do
    upstream = %Upstream{scheme: "http", host: "upstream.example", port: 8080}
    payload = "POST /widgets HTTP/1.1\r\nHost: upstream.example\r\n\r\n"

    assert UpstreamConnection.prepare_request(payload, upstream, :direct) == payload
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

  defp start_service_registry(records) do
    test = self()

    pid =
      spawn_link(fn ->
        Process.register(self(), ServiceRegistry)
        send(test, :service_registry_started)
        service_registry_loop(records)
      end)

    assert_receive :service_registry_started, 1_000
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :normal) end)
  end

  defp service_registry_loop(records) do
    receive do
      {:"$gen_call", {from, tag}, :all} ->
        send(from, {tag, records})
        service_registry_loop(records)

      {:"$gen_call", {from, tag}, :list_records} ->
        send(from, {tag, records |> Map.values() |> Enum.uniq_by(& &1.id)})
        service_registry_loop(records)
    end
  end
end
