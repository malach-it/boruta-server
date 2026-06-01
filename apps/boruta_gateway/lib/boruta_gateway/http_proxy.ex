defmodule BorutaGateway.HttpProxy do
  @moduledoc false

  require Logger

  use GenServer

  @connect_timeout 5_000
  @default_http_port 80
  @default_https_port 443

  alias BorutaGateway.Certificate
  alias BorutaGateway.ServiceRegistry

  defmodule Server do
    @moduledoc false

    use GenServer

    alias BorutaGateway.Certificate
    alias BorutaGateway.HttpProxy

    def start(args) do
      GenServer.start_link(__MODULE__, args)
    end

    @impl GenServer
    def init(args) do
      transport = Keyword.get(args, :transport, :tcp)

      {:ok, listen_socket} =
        listen(transport, args[:port])

      children =
        Enum.map(1..args[:num_acceptors], fn i ->
          Supervisor.child_spec(
            {HttpProxy, [listen_socket: listen_socket, downstream_transport: transport]},
            id: :"#{transport}_forward_proxy_acceptor_#{i}"
          )
        end)

      Process.flag(:trap_exit, true)

      with {:ok, supervisor} <- Supervisor.start_link(children, strategy: :one_for_one) do
        {:ok, supervisor: supervisor, listen_socket: listen_socket, transport: transport}
      end
    end

    @impl GenServer
    def handle_info({:EXIT, _pid, reason}, state) do
      close_listen_socket(state[:listen_socket], state[:transport])

      {:stop, reason, state}
    end

    @impl GenServer
    def terminate(_reason, state) do
      close_listen_socket(state[:listen_socket], state[:transport])
      stop_acceptor_supervisor(state[:supervisor])

      :ok
    end

    defp stop_acceptor_supervisor(nil), do: :ok

    defp stop_acceptor_supervisor(supervisor) do
      if Process.alive?(supervisor) do
        Supervisor.stop(supervisor, :normal, 5_000)
      end
    catch
      :exit, _reason -> :ok
    end

    defp listen(:ssl, port) do
      :ssl.listen(
        port,
        [
          {:packet, :raw},
          :binary,
          {:active, false},
          {:reuseaddr, true},
          {:verify, :verify_peer},
          {:fail_if_no_peer_cert, false},
          {:cacerts, Certificate.cacerts()}
        ] ++ Certificate.ssl_options()
      )
    end

    defp listen(:tcp, port) do
      :gen_tcp.listen(port, [
        {:packet, :raw},
        :binary,
        {:active, false},
        {:reuseaddr, true}
      ])
    end

    defp close_listen_socket(socket, :ssl), do: :ssl.close(socket)
    defp close_listen_socket(socket, _transport), do: :gen_tcp.close(socket)
  end

  defmodule HttpsServer do
    @moduledoc false

    alias BorutaGateway.HttpProxy

    def start(args) do
      args
      |> Keyword.put(:transport, :ssl)
      |> HttpProxy.Server.start()
    end
  end

  defmodule State do
    @moduledoc false

    defstruct [
      :listen_socket,
      :downstream_transport,
      :socket,
      :upstream_socket,
      :upstream_transport,
      :proxy_id
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    Process.flag(:trap_exit, true)
    send(self(), :accept)

    {:ok,
     %State{
       listen_socket: args[:listen_socket],
       downstream_transport: args[:downstream_transport] || :tcp
     }}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(:accept, state) do
    case accept_downstream(state.listen_socket, state.downstream_transport) do
      {:ok, socket} ->
        state = %{
          state
          | socket: socket,
            upstream_socket: nil,
            upstream_transport: nil,
            proxy_id: proxy_id()
        }

        log_proxy(:info, state, "accepted", downstream_transport: state.downstream_transport)

        {:noreply, state}

      {:error, error} ->
        log_accept_error(state, error)
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:tcp_closed, socket}, %State{socket: socket} = state) do
    {:noreply, close_downstream(state)}
  end

  def handle_info({:ssl_closed, socket}, %State{socket: socket} = state) do
    {:noreply, close_downstream(state)}
  end

  def handle_info({:tcp_closed, socket}, %State{upstream_socket: socket} = state) do
    {:noreply, close_exchange(state)}
  end

  def handle_info({:ssl_closed, socket}, %State{upstream_socket: socket} = state) do
    {:noreply, close_exchange(state)}
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket, upstream_socket: nil} = state) do
    handle_downstream_payload(state, payload)
  end

  def handle_info({:ssl, socket, payload}, %State{socket: socket, upstream_socket: nil} = state) do
    handle_downstream_payload(state, payload)
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket} = state) do
    send_upstream(state, payload)
    activate_downstream(socket, state.downstream_transport)

    {:noreply, state}
  end

  def handle_info({:ssl, socket, payload}, %State{socket: socket} = state) do
    send_upstream(state, payload)
    activate_downstream(socket, state.downstream_transport)

    {:noreply, state}
  end

  def handle_info({:tcp, socket, payload}, %State{upstream_socket: socket} = state) do
    send_downstream(state, payload)
    :inet.setopts(socket, active: :once)

    {:noreply, state}
  end

  def handle_info({:ssl, socket, payload}, %State{upstream_socket: socket} = state) do
    send_downstream(state, payload)
    :ssl.setopts(socket, active: :once)

    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  defp handle_downstream_payload(%State{} = state, payload) do
    case parse_request(payload) do
      {:connect, host, port} ->
        connect_tunnel(state, host, port)

      {:request, scheme, host, port, payload} ->
        forward_request(state, scheme, host, port, payload)

      :error ->
        log_proxy(:warning, state, "bad_request")
        send_downstream(state, "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
        {:noreply, close_downstream(state)}
    end
  end

  defp connect_tunnel(%State{} = state, host, port) do
    log_proxy(:info, state, "connect_tunnel", host: host, port: port)

    connect_tunnel_direct(state, host, port, resolve_upstream("https", host, port))
  end

  defp connect_tunnel_direct(%State{socket: socket} = state, host, port, resolved_upstream) do
    {_origin, connect_host, connect_port} = resolved_upstream

    case :gen_tcp.connect(
           String.to_charlist(connect_host),
           connect_port,
           socket_options(),
           @connect_timeout
         ) do
      {:ok, upstream_socket} ->
        log_proxy(:info, state, "direct_connect_tunnel",
          host: host,
          port: port,
          connect_host: connect_host,
          connect_port: connect_port
        )

        send_downstream(state, "HTTP/1.1 200 Connection Established\r\n\r\n")
        activate_downstream(socket, state.downstream_transport)
        :inet.setopts(upstream_socket, active: :once)

        {:noreply, %{state | upstream_socket: upstream_socket, upstream_transport: :tcp}}

      {:error, error} ->
        log_proxy(:warning, state, "direct_connect_tunnel_failed",
          host: host,
          port: port,
          connect_host: connect_host,
          connect_port: connect_port,
          reason: inspect(error)
        )

        send_downstream(state, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n")
        {:noreply, close_downstream(state)}
    end
  end

  defp forward_request(%State{} = state, scheme, host, port, payload)
       when scheme in ["http", "https"] do
    log_proxy(:info, state, "forward_request", scheme: scheme, host: host, port: port)

    forward_request_direct(
      state,
      scheme,
      host,
      port,
      payload,
      resolve_upstream(scheme, host, port)
    )
  end

  defp forward_request(%State{} = state, _scheme, _host, _port, _payload) do
    log_proxy(:warning, state, "unsupported_request")
    send_downstream(state, "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
    {:noreply, close_downstream(state)}
  end

  defp forward_request_direct(
         %State{socket: socket} = state,
         "http",
         _host,
         _port,
         payload,
         resolved_upstream
       ) do
    {_origin, connect_host, connect_port} = resolved_upstream

    case :gen_tcp.connect(
           String.to_charlist(connect_host),
           connect_port,
           socket_options(),
           @connect_timeout
         ) do
      {:ok, upstream_socket} ->
        log_proxy(:info, state, "direct_forward_request",
          scheme: "http",
          host: connect_host,
          port: connect_port
        )

        :gen_tcp.send(upstream_socket, payload)
        activate_downstream(socket, state.downstream_transport)
        :inet.setopts(upstream_socket, active: :once)

        {:noreply, %{state | upstream_socket: upstream_socket, upstream_transport: :tcp}}

      {:error, error} ->
        log_proxy(:warning, state, "direct_forward_request_failed",
          scheme: "http",
          host: connect_host,
          port: connect_port,
          reason: inspect(error)
        )

        send_downstream(state, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n")
        {:noreply, close_downstream(state)}
    end
  end

  defp forward_request_direct(
         %State{socket: socket} = state,
         "https",
         host,
         _port,
         payload,
         resolved_upstream
       ) do
    {origin, connect_host, connect_port} = resolved_upstream

    case :ssl.connect(
           String.to_charlist(connect_host),
           connect_port,
           ssl_options(origin, host),
           @connect_timeout
         ) do
      {:ok, upstream_socket} ->
        log_proxy(:info, state, "direct_forward_request",
          scheme: "https",
          host: connect_host,
          port: connect_port,
          origin: origin
        )

        :ssl.send(upstream_socket, payload)
        activate_downstream(socket, state.downstream_transport)
        :ssl.setopts(upstream_socket, active: :once)

        {:noreply, %{state | upstream_socket: upstream_socket, upstream_transport: :ssl}}

      {:error, error} ->
        log_proxy(:warning, state, "direct_forward_request_failed",
          scheme: "https",
          host: connect_host,
          port: connect_port,
          origin: origin,
          reason: inspect(error)
        )

        send_downstream(state, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n")
        {:noreply, close_downstream(state)}
    end
  end

  defp forward_request_direct(
         %State{} = state,
         _scheme,
         _host,
         _port,
         _payload,
         _resolved_upstream
       ) do
    log_proxy(:warning, state, "unsupported_direct_request")
    send_downstream(state, "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
    {:noreply, close_downstream(state)}
  end

  defp send_upstream(%State{upstream_socket: upstream_socket, upstream_transport: :ssl}, payload) do
    :ssl.send(upstream_socket, payload)
  end

  defp send_upstream(%State{upstream_socket: upstream_socket}, payload) do
    :gen_tcp.send(upstream_socket, payload)
  end

  defp parse_request(payload) do
    with {:ok, header, body} <- split_headers(payload),
         {:ok, method, target, version} <- parse_request_line(header) do
      parse_request(method, target, version, header, body)
    else
      _ -> :error
    end
  end

  defp parse_request("CONNECT", target, _version, _header, _body) do
    case parse_authority(target, @default_https_port) do
      {:ok, host, port} -> {:connect, host, port}
      :error -> :error
    end
  end

  defp parse_request(method, target, version, header, body) do
    with {:ok, scheme, host, port, path} <- parse_request_target(target, header),
         payload <- build_origin_form_payload(method, path, version, header, body, host, port) do
      {:request, scheme, host, port, payload}
    else
      _ -> :error
    end
  end

  defp parse_request_line(header) do
    header
    |> String.split("\r\n", parts: 2)
    |> List.first()
    |> case do
      nil ->
        :error

      line ->
        case String.split(line, " ", parts: 3) do
          [method, target, version] -> {:ok, method, target, version}
          _ -> :error
        end
    end
  end

  defp parse_request_target(target, header) do
    case URI.parse(target) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) ->
        port = uri.port || default_port(scheme)
        path = origin_form(uri)
        {:ok, scheme, host, port, path}

      %URI{scheme: nil} ->
        with {:ok, host, port} <- host_header(header) do
          {:ok, "http", host, port, target}
        end

      _ ->
        :error
    end
  end

  defp origin_form(%URI{path: nil, query: nil}), do: "/"
  defp origin_form(%URI{path: nil, query: query}), do: "/?#{query}"
  defp origin_form(%URI{path: path, query: nil}), do: path
  defp origin_form(%URI{path: path, query: query}), do: "#{path}?#{query}"

  defp host_header(header) do
    header
    |> header_value("host")
    |> case do
      nil -> :error
      host -> parse_authority(host, @default_http_port)
    end
  end

  defp parse_authority(authority, default_port) do
    uri = URI.parse("//#{authority}")

    case uri do
      %URI{host: host, port: port} when is_binary(host) ->
        {:ok, host, port || default_port}

      _ ->
        :error
    end
  end

  defp build_origin_form_payload(method, path, version, header, body, host, port) do
    [_request_line | header_lines] = String.split(header, "\r\n")

    header =
      header_lines
      |> reject_hop_by_hop_headers()
      |> put_host_header(host, port)
      |> then(fn lines ->
        Enum.join([Enum.join([method, path, version], " ") | lines], "\r\n")
      end)

    header <> "\r\n\r\n" <> body
  end

  defp reject_hop_by_hop_headers(header_lines) do
    rejected_headers = [
      "connection",
      "keep-alive",
      "proxy-authenticate",
      "proxy-authorization",
      "te",
      "trailer",
      "transfer-encoding",
      "upgrade"
    ]

    Enum.reject(header_lines, fn line -> header_name(line) in rejected_headers end)
  end

  defp put_host_header(header_lines, host, port) do
    ["Host: #{host_header_value(host, port)}" | header_lines]
  end

  defp host_header_value(host, @default_http_port), do: host
  defp host_header_value(host, @default_https_port), do: host
  defp host_header_value(host, port), do: "#{host}:#{port}"

  defp header_value(header, name) do
    header
    |> String.split("\r\n")
    |> Enum.find_value(fn line ->
      case String.split(line, ":", parts: 2) do
        [header_name, value] ->
          if String.downcase(header_name) == name, do: String.trim(value)

        _ ->
          nil
      end
    end)
  end

  defp header_name(header_line) do
    header_line
    |> String.split(":", parts: 2)
    |> List.first()
    |> String.downcase()
  end

  defp split_headers(payload) do
    case String.split(payload, "\r\n\r\n", parts: 2) do
      [header, body] -> {:ok, header, body}
      [_partial_header] -> :error
    end
  end

  defp default_port("http"), do: @default_http_port
  defp default_port("https"), do: @default_https_port

  defp resolve_upstream(scheme, host, port) do
    resolve_direct_upstream(scheme, host, port)
  end

  defp resolve_direct_upstream(scheme, host, port) do
    case ServiceRegistry.all()[host] do
      %{ip_address: ip_address, status: "online"}
      when is_binary(ip_address) ->
        {:service_registry, ip_address, sidecar_port(scheme)}

      _record ->
        {:external, host, port}
    end
  end

  defp sidecar_port("http") do
    Application.fetch_env!(:boruta_gateway, :sidecar_port)
  end

  defp sidecar_port("https") do
    Application.fetch_env!(:boruta_gateway, :sidecar_https_port)
  end

  defp socket_options do
    [:binary, {:packet, :raw}, {:active, false}]
  end

  defp accept_downstream(listen_socket, :ssl) do
    with {:ok, socket} <- :ssl.transport_accept(listen_socket),
         {:ok, socket} <- :ssl.handshake(socket) do
      activate_downstream(socket, :ssl)
      {:ok, socket}
    end
  end

  defp accept_downstream(listen_socket, :tcp) do
    with {:ok, socket} <- :gen_tcp.accept(listen_socket) do
      activate_downstream(socket, :tcp)
      {:ok, socket}
    end
  end

  defp activate_downstream(socket, :ssl), do: :ssl.setopts(socket, active: :once)
  defp activate_downstream(socket, _transport), do: :inet.setopts(socket, active: :once)

  defp send_downstream(%State{socket: socket, downstream_transport: :ssl}, payload) do
    :ssl.send(socket, payload)
  end

  defp send_downstream(%State{socket: socket}, payload) do
    :gen_tcp.send(socket, payload)
  end

  defp ssl_options(:service_registry, host) do
    socket_options() ++
      [
        {:verify, :verify_peer},
        {:server_name_indication, String.to_charlist(host)},
        {:customize_hostname_check, [fqdn: String.to_charlist(host)]},
        {:cacerts, Certificate.cacerts()}
      ]
  end

  defp ssl_options(:external, host) do
    socket_options() ++
      [
        {:verify, :verify_peer},
        {:server_name_indication, String.to_charlist(host)},
        {:customize_hostname_check, [fqdn: String.to_charlist(host)]},
        {:cacerts, Certificate.cacerts()}
      ]
  end

  defp close_downstream(%State{socket: socket} = state) do
    close_socket(socket, state.downstream_transport)
    send(self(), :accept)

    %{state | socket: nil, upstream_socket: nil, upstream_transport: nil}
  end

  defp close_exchange(%State{} = state) do
    close_socket(state.socket, state.downstream_transport)
    close_socket(state.upstream_socket, state.upstream_transport)
    send(self(), :accept)

    %{state | socket: nil, upstream_socket: nil, upstream_transport: nil}
  end

  defp close_socket(nil, _transport), do: :ok
  defp close_socket(socket, :ssl), do: :ssl.close(socket)
  defp close_socket(socket, _transport), do: :gen_tcp.close(socket)

  defp proxy_id do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string(16)
  end

  defp log_proxy(level, %State{} = state, event, attrs \\ []) do
    Logger.log(
      level,
      fn ->
        [
          "boruta_gateway proxy ",
          event
          | Enum.map(attrs, fn {key, value} -> log_attribute(key, value) end)
        ]
      end,
      application: :boruta_gateway,
      proxy_id: state.proxy_id,
      type: :proxy
    )
  end

  defp log_accept_error(state, error) when error in [:closed, :einval] do
    log_proxy(:debug, state, "accept_closed", reason: inspect(error))
  end

  defp log_accept_error(state, error) do
    log_proxy(:warning, state, "accept_failed", reason: inspect(error))
  end

  defp log_attribute(_key, nil), do: ""
  defp log_attribute(key, value), do: [" ", Atom.to_string(key), "=", to_string(value)]
end
