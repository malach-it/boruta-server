defmodule BorutaGateway.HttpProxyTest do
  use ExUnit.Case

  alias BorutaGateway.Certificate
  alias BorutaGateway.CertificateHelpers
  alias BorutaGateway.HttpProxy
  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Record

  test "requires a trusted client certificate" do
    start_service_registry(%{})

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    case :ssl.connect(~c"localhost", proxy_port, [:binary, active: false, verify: :verify_none]) do
      {:error, reason} ->
        assert false, "expected TLS handshake to complete, got: #{inspect(reason)}"

      {:ok, socket} ->
        assert {:error, _reason} = :ssl.recv(socket, 0, 1_000)
        :ssl.close(socket)
    end

    GenServer.stop(proxy)
  end

  test "CONNECT establishes a TCP tunnel" do
    start_service_registry(%{})

    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        :ok = :gen_tcp.send(socket, "echo:" <> payload)
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "CONNECT localhost:#{upstream_port} HTTP/1.1\r\nHost: localhost:#{upstream_port}\r\n\r\n"
      )

    assert {:ok, response} = :ssl.recv(socket, 0, 5_000)
    assert response == "HTTP/1.1 200 Connection Established\r\n\r\n"

    :ok = :ssl.send(socket, "payload")

    assert {:ok, "echo:payload"} = :ssl.recv(socket, 0, 5_000)

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "logs CONNECT tunnel requests" do
    start_service_registry(%{})

    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    parent = self()
    handler_id = :http_proxy_connect_request_log_test

    :telemetry.attach(
      handler_id,
      [:boruta_gateway, :request, :stop],
      fn _event, measurements, metadata, _config ->
        send(parent, {:proxy_request_log, measurements, metadata})
      end,
      :ok
    )

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    try do
      {:ok, socket} = proxy_connect(proxy_port)

      :ok =
        :ssl.send(
          socket,
          "CONNECT localhost:#{upstream_port} HTTP/1.1\r\nHost: localhost:#{upstream_port}\r\n\r\n"
        )

      assert {:ok, "HTTP/1.1 200 Connection Established\r\n\r\n"} =
               :ssl.recv(socket, 0, 5_000)

      assert_receive {:proxy_request_log, %{duration: duration},
                      %{
                        method: "CONNECT",
                        path: "localhost:" <> _,
                        status: 200,
                        tls: "tls"
                      }},
                     1_000

      assert duration > 0

      :ssl.close(socket)
    after
      :telemetry.detach(handler_id)
      GenServer.stop(proxy)
    end

    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "forwards absolute-form HTTP requests as origin-form upstream requests" do
    start_service_registry(%{})

    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    parent = self()

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        send(parent, {:upstream_request, payload})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "GET http://localhost:#{upstream_port}/forwarded?x=1 HTTP/1.1\r\n" <>
          "Host: ignored.example\r\nProxy-Authorization: basic stale\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
             :ssl.recv(socket, 0, 5_000)

    assert_receive {:upstream_request, upstream_request}, 1_000
    assert upstream_request =~ "GET /forwarded?x=1 HTTP/1.1\r\n"
    assert upstream_request =~ "Host: localhost:#{upstream_port}\r\n"
    refute upstream_request =~ "Proxy-Authorization"

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "logs forwarded HTTP requests with upstream response status" do
    start_service_registry(%{})

    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, _payload} = :gen_tcp.recv(socket, 0, 5_000)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    parent = self()
    handler_id = :http_proxy_forwarded_request_log_test

    :telemetry.attach(
      handler_id,
      [:boruta_gateway, :request, :stop],
      fn _event, measurements, metadata, _config ->
        send(parent, {:proxy_request_log, measurements, metadata})
      end,
      :ok
    )

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    try do
      {:ok, socket} = proxy_connect(proxy_port)

      :ok =
        :ssl.send(
          socket,
          "GET http://localhost:#{upstream_port}/forwarded?x=1 HTTP/1.1\r\n" <>
            "Host: ignored.example\r\n\r\n"
        )

      assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
               :ssl.recv(socket, 0, 5_000)

      :ssl.close(socket)

      assert_receive {:proxy_request_log, %{duration: duration},
                      %{
                        method: "GET",
                        path: "/forwarded?x=1",
                        status: 204,
                        tls: "tls"
                      }},
                     1_000

      assert duration > 0
    after
      :telemetry.detach(handler_id)
      GenServer.stop(proxy)
    end

    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "forwards requests received over TLS" do
    start_service_registry(%{})

    root_ca = Certificate.generate_root_ca_pem!()
    CertificateHelpers.regenerate_certificate!(root_ca)
    Certificate.load_trusted_certificates!([root_ca.certificate])

    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    parent = self()

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        send(parent, {:upstream_request, payload})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "GET http://localhost:#{upstream_port}/secure-proxy HTTP/1.1\r\n" <>
          "Host: ignored.example\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
             :ssl.recv(socket, 0, 5_000)

    assert_receive {:upstream_request, upstream_request}, 1_000
    assert upstream_request =~ "GET /secure-proxy HTTP/1.1\r\n"
    assert upstream_request =~ "Host: localhost:#{upstream_port}\r\n"

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "forwards registered service HTTP requests to the sidecar HTTP port" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    start_service_registry(%{
      "service.local" => %Record{
        id: SecureRandom.uuid(),
        node_name: "service-node",
        ip_address: "127.0.0.1",
        aliases: ["service.local"],
        configuration: sidecar_configuration("http", upstream_port),
        status: "online"
      }
    })

    parent = self()

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        send(parent, {:upstream_request, payload})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "GET http://service.local/origin HTTP/1.1\r\nHost: service.local\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
             :ssl.recv(socket, 0, 5_000)

    assert_receive {:upstream_request, upstream_request}, 1_000
    assert upstream_request =~ "GET /origin HTTP/1.1\r\n"
    assert upstream_request =~ "Host: service.local\r\n"

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "connects registered service tunnels to the sidecar HTTPS port" do
    {:ok, upstream_listener} = listen()
    {:ok, {_address, upstream_port}} = :inet.sockname(upstream_listener)

    start_service_registry(%{
      "service.local" => %Record{
        id: SecureRandom.uuid(),
        node_name: "service-node",
        ip_address: "127.0.0.1",
        aliases: ["service.local"],
        configuration: sidecar_configuration("https", upstream_port),
        status: "online"
      }
    })

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :gen_tcp.accept(upstream_listener)
        {:ok, payload} = :gen_tcp.recv(socket, 0, 5_000)
        :ok = :gen_tcp.send(socket, "echo:" <> payload)
        :gen_tcp.close(socket)
        :gen_tcp.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "CONNECT service.local:443 HTTP/1.1\r\nHost: service.local:443\r\n\r\n"
      )

    assert {:ok, response} = :ssl.recv(socket, 0, 5_000)
    assert response == "HTTP/1.1 200 Connection Established\r\n\r\n"

    :ok = :ssl.send(socket, "payload")

    assert {:ok, "echo:payload"} = :ssl.recv(socket, 0, 5_000)

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  test "sends a client certificate when the registered HTTPS sidecar requires one" do
    root_ca = Certificate.generate_root_ca_pem!()
    CertificateHelpers.regenerate_certificate!(root_ca)
    Certificate.load_trusted_certificates!([root_ca.certificate])

    {:ok, upstream_listener} = ssl_listen(true)
    {:ok, {_address, upstream_port}} = :ssl.sockname(upstream_listener)

    start_service_registry(%{
      "__cluster_ca__" => %Record{
        id: SecureRandom.uuid(),
        node_name: "__cluster_ca__",
        ip_address: "__cluster_ca__",
        aliases: [],
        certificate: root_ca.certificate,
        private_key: root_ca.private_key,
        status: "root"
      },
      "localhost" => %Record{
        id: SecureRandom.uuid(),
        node_name: "service-node",
        ip_address: "127.0.0.1",
        aliases: ["localhost"],
        certificate: Certificate.pem(),
        configuration: sidecar_configuration("https", upstream_port, true),
        status: "online"
      }
    })

    parent = self()

    {upstream, upstream_ref} =
      spawn_monitor(fn ->
        {:ok, socket} = :ssl.transport_accept(upstream_listener)
        {:ok, socket} = :ssl.handshake(socket)
        send(parent, {:upstream_peer_certificate, :ssl.peercert(socket)})
        {:ok, payload} = :ssl.recv(socket, 0, 5_000)
        send(parent, {:upstream_request, payload})
        :ok = :ssl.send(socket, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        :ssl.close(socket)
        :ssl.close(upstream_listener)
      end)

    {:ok, proxy_port} = free_port()
    {:ok, proxy} = HttpProxy.HttpsServer.start(port: proxy_port, num_acceptors: 1)

    {:ok, socket} = proxy_connect(proxy_port)

    :ok =
      :ssl.send(
        socket,
        "GET https://localhost/secure HTTP/1.1\r\nHost: localhost\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"} =
             :ssl.recv(socket, 0, 5_000)

    assert_receive {:upstream_peer_certificate, {:ok, _certificate}}, 1_000
    assert_receive {:upstream_request, upstream_request}, 1_000
    assert upstream_request =~ "GET /secure HTTP/1.1\r\n"
    assert upstream_request =~ "Host: localhost\r\n"

    :ssl.close(socket)
    GenServer.stop(proxy)
    assert_receive {:DOWN, ^upstream_ref, :process, ^upstream, :normal}, 1_000
  end

  defp sidecar_configuration(scheme, port, verify_client_certificate \\ false) do
    %{
      "services" => [
        %{
          "name" => "#{String.upcase(scheme)} sidecar gateway",
          "type" => "gateway",
          "scheme" => scheme,
          "enabled" => true,
          "port" => port,
          "verify_client_certificate" => verify_client_certificate
        }
      ]
    }
  end

  defp listen do
    :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
  end

  defp ssl_listen(verify_client_certificate) do
    :ssl.listen(
      0,
      [:binary, {:packet, :raw}, {:active, false}, {:reuseaddr, true}] ++
        client_certificate_options(verify_client_certificate) ++
        Certificate.ssl_options()
    )
  end

  defp client_certificate_options(true) do
    [verify: :verify_peer, fail_if_no_peer_cert: true, cacerts: Certificate.cacerts()]
  end

  defp client_certificate_options(false), do: []

  defp free_port do
    {:ok, socket} = listen()
    {:ok, {_address, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)

    {:ok, port}
  end

  defp proxy_connect(port) do
    :ssl.connect(
      ~c"localhost",
      port,
      [:binary, active: false, verify: :verify_none] ++ Certificate.ssl_options()
    )
  end

  defp start_service_registry(records) do
    case Process.whereis(ServiceRegistry) do
      nil ->
        test = self()

        pid =
          spawn_link(fn ->
            Process.register(self(), ServiceRegistry)
            send(test, :service_registry_started)
            service_registry_loop(records)
          end)

        assert_receive :service_registry_started, 1_000

        on_exit(fn -> stop_service_registry(pid) end)

      pid ->
        previous_state = :sys.get_state(pid)

        :sys.replace_state(pid, fn state -> %{state | records: records} end)

        on_exit(fn -> restore_service_registry_state(pid, previous_state) end)
    end
  end

  defp stop_service_registry(pid) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
  end

  defp restore_service_registry_state(pid, previous_state) do
    if Process.alive?(pid), do: :sys.replace_state(pid, fn _state -> previous_state end)
  end

  defp service_registry_loop(records) do
    receive do
      {:"$gen_call", {from, tag}, :all} ->
        send(from, {tag, records})
        service_registry_loop(records)

      {:"$gen_call", {from, tag}, :list_records} ->
        send(from, {tag, list_service_registry_records(records)})
        service_registry_loop(records)
    end
  end

  defp list_service_registry_records(records) do
    records
    |> Map.values()
    |> Enum.uniq_by(& &1.id)
  end
end
