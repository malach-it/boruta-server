defmodule BorutaGateway.HttpsGatewayTest do
  use ExUnit.Case

  alias BorutaGateway.Certificate
  alias BorutaGateway.HttpsGateway

  test "closes malformed TLS connections and continues accepting" do
    {:ok, gateway_port} = free_port()

    {:ok, gateway} =
      HttpsGateway.Server.start(
        port: gateway_port,
        num_acceptors: 1,
        handshake_timeout: 1_000,
        match_function: fn _host, _path -> nil end,
        ssl_options: Certificate.ssl_options()
      )

    Process.unlink(gateway)
    gateway_ref = Process.monitor(gateway)

    on_exit(fn ->
      if Process.alive?(gateway), do: Process.exit(gateway, :kill)
    end)

    {:ok, malformed_socket} =
      :gen_tcp.connect(~c"localhost", gateway_port, [:binary, active: false], 1_000)

    :ok = :gen_tcp.send(malformed_socket, "not a TLS handshake")
    assert_tcp_closed(malformed_socket)

    assert {:ok, socket} =
             :ssl.connect(
               ~c"localhost",
               gateway_port,
               [:binary, active: false, verify: :verify_none],
               2_000
             )

    :ssl.close(socket)
    assert Process.alive?(gateway)
    refute_received {:DOWN, ^gateway_ref, :process, ^gateway, _reason}
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    {:ok, port}
  end

  defp assert_tcp_closed(socket) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, _tls_alert} -> assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
      {:error, :closed} -> :ok
    end
  end
end
