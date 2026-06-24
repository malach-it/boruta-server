defmodule BorutaGateway.HttpsGateway do
  @moduledoc false

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
  end

  use GenServer

  alias BorutaAuth.Plugs.RateLimit.Counter
  alias BorutaGateway.Certificate
  alias BorutaGateway.HttpsGateway.Authorization
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  @connect_timeout 5_000
  @default_max_response_buffer_bytes 10_000_000

  defmodule Server do
    @moduledoc false

    use Supervisor

    alias BorutaGateway.HttpsGateway

    def start(args) do
      Supervisor.start_link(__MODULE__, args)
    end

    @impl Supervisor
    def init(args) do
      verify_client_certificate =
        resolve_verify_client_certificate(args[:verify_client_certificate])

      ssl_options = server_ssl_options(args)

      {:ok, listen_socket} =
        :ssl.listen(
          args[:port],
          [
            {:packet, :raw},
            :binary,
            {:active, false},
            {:reuseaddr, true}
          ] ++
            ssl_options ++
            client_certificate_options(verify_client_certificate)
        )

      children =
        Enum.map(1..args[:num_acceptors], fn i ->
          Supervisor.child_spec(
            {HttpsGateway,
             [
               listen_socket: listen_socket,
               match_function: args[:match_function]
             ]},
            id: :"https_proxy_server_acceptor_#{i}"
          )
        end)

      Supervisor.init(children, strategy: :one_for_one)
    end

    defp client_certificate_options(true) do
      [
        {:verify, :verify_peer},
        {:fail_if_no_peer_cert, true},
        {:cacerts, Certificate.cacerts()}
      ]
    end

    defp client_certificate_options(_verify_client_certificate), do: []

    defp server_ssl_options(args) do
      case Keyword.fetch(args, :ssl_options) do
        {:ok, ssl_options} -> ssl_options
        :error -> Certificate.ssl_options()
      end
    end

    defp resolve_verify_client_certificate({module, function, args}) do
      apply(module, function, args)
    end

    defp resolve_verify_client_certificate(verify_client_certificate),
      do: verify_client_certificate
  end

  defmodule State do
    @moduledoc false

    defstruct [
      :listen_socket,
      :match_function,
      :socket,
      :client_socket,
      :start,
      :upstream_start,
      :request_id,
      :method,
      :path,
      :remote_ip,
      :upstream,
      :request,
      :response,
      :response_headers_sent,
      :content_length
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
       match_function: args[:match_function] || (&Upstreams.match/1)
     }}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(:accept, state) do
    case accept_downstream(state.listen_socket) do
      {:ok, socket} ->
        {:noreply, reset_exchange(state, socket)}

      {:error, _error} ->
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %State{socket: socket} = state) do
    case accept_downstream(state.listen_socket) do
      {:ok, socket} ->
        {:noreply, reset_exchange(state, socket)}

      {:error, _error} ->
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:tcp_closed, socket}, %State{client_socket: socket} = state) do
    {:noreply, close_exchange(state, socket, :tcp)}
  end

  def handle_info({:ssl_closed, socket}, %State{client_socket: socket} = state) do
    {:noreply, close_exchange(state, socket, :ssl)}
  end

  def handle_info({:ssl, socket, payload}, %State{socket: socket, client_socket: nil} = state) do
    payload = buffered_request_payload(state, payload)

    if request_headers_complete?(payload) do
      handle_downstream_request(socket, payload, state)
    else
      :ssl.setopts(socket, active: :once)

      {:noreply, %{state | request: payload}}
    end
  end

  def handle_info({:tcp, socket, payload}, %State{client_socket: socket} = state) do
    forward_response_payload(state, socket, payload, :tcp)
  end

  def handle_info({:ssl, socket, payload}, %State{client_socket: socket} = state) do
    forward_response_payload(state, socket, payload, :ssl)
  end

  def handle_info({:ssl, socket, payload}, %State{socket: socket} = state) do
    activate_downstream(socket)

    case state.client_socket do
      {:sslsocket, _, _} ->
        :ssl.send(state.client_socket, payload)

      _ ->
        :gen_tcp.send(state.client_socket, payload)
    end

    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  defp handle_downstream_request(socket, payload, state) do
    start = :os.system_time(:microsecond)
    request_id = request_id(payload)
    state = %{state | remote_ip: request_remote_ip(payload, socket), request: nil}

    case parse_request_line(payload) do
      {:ok, method, path} ->
        path_info = path_info(path)

        with %Upstream{} = upstream <- match_upstream(state.match_function, payload, path_info),
             :ok <- rate_limit(socket, upstream),
             {:ok, token} <- Authorization.authorize(payload, method, upstream) do
          connect_upstream(
            socket,
            payload,
            state,
            upstream,
            token,
            %{
              start: start,
              request_id: request_id,
              method: method,
              path: path
            }
          )
        else
          nil ->
            response = "No upstream has been found corresponding to the given request."

            send_downstream(
              socket,
              "HTTP/1.1 404 Not Found\r\n" <>
                "Content-Length: 62\r\n\r\n" <>
                response
            )

            log_exchange(state, start, request_id, method, path, nil, 404, :failure)

            {:noreply, close_downstream(socket, state)}

          {:unauthorized, content_type, response} ->
            send_downstream(
              socket,
              "HTTP/1.1 401 Unauthorized\r\n" <>
                "Content-Type: #{content_type}\r\n" <>
                "Content-Length: #{byte_size(response)}\r\n\r\n" <>
                response
            )

            log_exchange(state, start, request_id, method, path, nil, 401, :failure)

            {:noreply, close_downstream(socket, state)}

          {:forbidden, content_type, response} ->
            send_downstream(
              socket,
              "HTTP/1.1 403 Forbidden\r\n" <>
                "Content-Type: #{content_type}\r\n" <>
                "Content-Length: #{byte_size(response)}\r\n\r\n" <>
                response
            )

            log_exchange(state, start, request_id, method, path, nil, 403, :failure)

            {:noreply, close_downstream(socket, state)}

          :rate_limited ->
            send_downstream(socket, "HTTP/1.1 429 Too Many Requests\r\nContent-Length: 0\r\n\r\n")
            log_exchange(state, start, request_id, method, path, nil, 429, :failure)

            {:noreply, close_downstream(socket, state)}
        end

      {:error, :bad_request} ->
        send_downstream(socket, "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")

        {:noreply, close_downstream(socket, state)}
    end
  end

  @impl GenServer
  def terminate(reason, _state) do
    {:stop, reason}
  end

  defp connect_upstream(socket, payload, state, upstream, token, request) do
    case upstream.scheme do
      "http" ->
        case :gen_tcp.connect(
               upstream.host |> String.to_charlist(),
               upstream.port,
               upstream_socket_options(upstream),
               @connect_timeout
             ) do
          {:ok, client_socket} ->
            :ok = :gen_tcp.send(client_socket, transform_header(payload, upstream, token))
            upstream_start = :os.system_time(:microsecond)

            activate_downstream(socket)
            :inet.setopts(client_socket, active: :once)

            {:noreply,
             %{
               state
               | client_socket: client_socket,
                 start: request.start,
                 upstream_start: upstream_start,
                 request_id: request.request_id,
                 method: request.method,
                 path: request.path,
                 remote_ip: state.remote_ip,
                 upstream: upstream
             }}

          {:error, _error} ->
            send_downstream(socket, "HTTP/1.1 503 Service Unavailable\r\n\r\n")

            log_exchange(
              state,
              request.start,
              request.request_id,
              request.method,
              request.path,
              upstream,
              503,
              :failure
            )

            {:noreply, close_downstream(socket, state)}
        end

      "https" ->
        case :ssl.connect(
               upstream.host |> String.to_charlist(),
               upstream.port,
               upstream_ssl_options(upstream),
               @connect_timeout
             ) do
          {:ok, client_socket} ->
            _connected = :os.system_time(:microsecond) - request.start
            :ok = :ssl.send(client_socket, transform_header(payload, upstream, token))
            upstream_start = :os.system_time(:microsecond)

            activate_downstream(socket)
            :ssl.setopts(client_socket, active: :once)

            {:noreply,
             %{
               state
               | client_socket: client_socket,
                 start: request.start,
                 upstream_start: upstream_start,
                 request_id: request.request_id,
                 method: request.method,
                 path: request.path,
                 remote_ip: state.remote_ip,
                 upstream: upstream
             }}

          {:error, _error} ->
            send_downstream(socket, "HTTP/1.1 503 Service Unavailable\r\n\r\n")

            log_exchange(
              state,
              request.start,
              request.request_id,
              request.method,
              request.path,
              upstream,
              503,
              :failure
            )

            {:noreply, close_downstream(socket, state)}
        end
    end
  end

  defp forward_response_payload(
         %State{response_headers_sent: true} = state,
         socket,
         payload,
         transport
       ) do
    response = (state.response || "") <> payload

    if response_buffer_exceeded?(response) do
      {:noreply, close_buffered_response(state, socket, transport)}
    else
      send_downstream(state.socket, payload)
      state = %{state | response: response}

      case message_complete?(response) do
        true ->
          {:noreply, close_exchange(state, socket, transport)}

        false ->
          activate_upstream_socket(socket, transport)
          {:noreply, state}
      end
    end
  end

  defp forward_response_payload(state, socket, payload, transport) do
    response = (state.response || "") <> payload

    if response_buffer_exceeded?(response) do
      send_downstream(state.socket, "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n")

      {:noreply,
       close_exchange(%{state | response: "HTTP/1.1 502 Bad Gateway"}, socket, transport)}
    else
      case split_headers(response) do
        {:ok, header, body} ->
          send_downstream(state.socket, clean_response_headers(header) <> "\r\n\r\n" <> body)

          case message_complete?(response) do
            true ->
              {:noreply, close_exchange(%{state | response: response}, socket, transport)}

            false ->
              activate_upstream_socket(socket, transport)
              {:noreply, %{state | response: response, response_headers_sent: true}}
          end

        :error ->
          activate_upstream_socket(socket, transport)
          {:noreply, %{state | response: response}}
      end
    end
  end

  defp close_buffered_response(state, socket, transport) do
    close_exchange(%{state | response: nil}, socket, transport)
  end

  defp activate_upstream_socket(socket, :tcp), do: :inet.setopts(socket, active: :once)
  defp activate_upstream_socket(socket, :ssl), do: :ssl.setopts(socket, active: :once)

  @doc false
  def upstream_socket_options(%Upstream{}) do
    [:binary, {:packet, :raw}, {:active, false}]
  end

  defp upstream_ssl_options(%Upstream{} = upstream) do
    upstream_socket_options(upstream) ++
      [
        {:verify, :verify_peer},
        {:server_name_indication, String.to_charlist(upstream.host)},
        {:customize_hostname_check, [fqdn: String.to_charlist(upstream.host)]},
        {:cacerts, Certificate.gateway_cacerts()}
      ] ++ mtls_options(upstream)
  end

  defp mtls_options(%Upstream{mtls_enabled: true}) do
    Certificate.ssl_options()
  end

  defp mtls_options(%Upstream{}), do: []

  defp accept_downstream(listen_socket) do
    with {:ok, socket} <- :ssl.transport_accept(listen_socket),
         {:ok, socket} <- :ssl.handshake(socket) do
      activate_downstream(socket)
      {:ok, socket}
    end
  end

  defp activate_downstream(socket), do: :ssl.setopts(socket, active: :once)
  defp send_downstream(socket, payload), do: :ssl.send(socket, payload)
  defp close_downstream_socket(socket), do: :ssl.close(socket)

  defp reset_exchange(state, socket) do
    %{
      state
      | socket: socket,
        client_socket: nil,
        response: nil,
        response_headers_sent: false
    }
  end

  defp close_downstream(socket, state) do
    close_downstream_socket(socket)
    send(self(), :accept)

    %{
      state
      | socket: nil,
        client_socket: nil,
        start: nil,
        upstream_start: nil,
        request_id: nil,
        method: nil,
        path: nil,
        remote_ip: nil,
        upstream: nil,
        request: nil,
        response: nil,
        response_headers_sent: false
    }
  end

  defp close_exchange(state, upstream_socket, :tcp) do
    log_completed_exchange(state)
    close_downstream_socket(state.socket)
    :gen_tcp.close(upstream_socket)
    send(self(), :accept)

    %{
      state
      | socket: nil,
        client_socket: nil,
        start: nil,
        upstream_start: nil,
        request_id: nil,
        method: nil,
        path: nil,
        remote_ip: nil,
        upstream: nil,
        request: nil,
        response: nil,
        response_headers_sent: false
    }
  end

  defp close_exchange(state, upstream_socket, :ssl) do
    log_completed_exchange(state)
    close_downstream_socket(state.socket)
    :ssl.close(upstream_socket)
    send(self(), :accept)

    %{
      state
      | socket: nil,
        client_socket: nil,
        start: nil,
        upstream_start: nil,
        request_id: nil,
        method: nil,
        path: nil,
        remote_ip: nil,
        upstream: nil,
        request: nil,
        response: nil,
        response_headers_sent: false
    }
  end

  defp rate_limit(
         socket,
         %Upstream{
           rate_limit_enabled: true,
           rate_limit_count: count,
           rate_limit_time_unit: time_unit,
           rate_limit_penality: penality,
           rate_limit_timeout: max_timeout,
           rate_limit_memory_length: memory_length
         } = upstream
       ) do
    time_unit = String.to_existing_atom(time_unit)
    key = {:gateway_upstream, upstream.id, remote_ip(socket)}

    case Counter.throttling_timeout(key, count, time_unit, penality, memory_length) do
      timeout when timeout < max_timeout ->
        :timer.sleep(timeout)
        Counter.increment(key, time_unit, memory_length)
        :ok

      _ ->
        :rate_limited
    end
  end

  defp rate_limit(_socket, %Upstream{}), do: :ok

  defp remote_ip(socket) do
    case :ssl.peername(socket) do
      {:ok, {address, _port}} -> :inet.ntoa(address)
      _error -> :unknown
    end
  end

  defp request_remote_ip(payload, socket) do
    forwarded_remote_ip(payload) || remote_ip(socket)
  end

  defp forwarded_remote_ip(payload) do
    real_ip_header(payload) ||
      x_forwarded_for_header(payload) ||
      forwarded_header(payload)
  end

  defp real_ip_header(payload) do
    case Regex.run(~r{(?:^|\r\n)x-real-ip:\s*([^\r]+)}i, payload) do
      [_, remote_ip] -> String.trim(remote_ip)
      nil -> nil
    end
  end

  defp x_forwarded_for_header(payload) do
    case Regex.run(~r{(?:^|\r\n)x-forwarded-for:\s*([^\r]+)}i, payload) do
      [_, remote_ips] ->
        remote_ips
        |> String.split(",", parts: 2)
        |> List.first()
        |> String.trim()

      nil ->
        nil
    end
  end

  defp forwarded_header(payload) do
    case Regex.run(~r{(?:^|\r\n)forwarded:\s*[^\r]*for=\"?([^\";\r,]+)\"?}i, payload) do
      [_, remote_ip] ->
        remote_ip |> String.trim() |> String.trim_leading("[") |> String.trim_trailing("]")

      nil ->
        nil
    end
  end

  defp request_host(payload) do
    case Regex.run(~r{(?:^|\r\n)host:\s*([^\r]+)}i, payload) do
      [_, host] -> host
      nil -> nil
    end
  end

  defp buffered_request_payload(%State{request: nil}, payload), do: payload
  defp buffered_request_payload(%State{request: request}, payload), do: request <> payload

  defp request_headers_complete?(payload), do: String.contains?(payload, "\r\n\r\n")

  defp match_upstream(match_function, payload, path_info) do
    case :erlang.fun_info(match_function, :arity) do
      {:arity, 2} -> match_function.(request_host(payload), path_info)
      {:arity, 1} -> match_function.(path_info)
    end
  end

  defp request_id(payload) do
    case Regex.run(~r{[X|x]-[R|r]equest-[I|i]d\: ([^\r]+)}, payload) do
      [_, request_id] -> request_id
      nil -> SecureRandom.hex(4)
    end
  end

  defp parse_request_line(payload) do
    case Regex.run(~r{^(GET|POST|PUT|PATCH|OPTIONS|DELETE|HEAD) ([^\s]+)}, payload) do
      [_, method, path] -> {:ok, method, path}
      _ -> {:error, :bad_request}
    end
  end

  defp path_info(path) do
    path
    |> String.split("?", parts: 2)
    |> List.first()
    |> String.split("/", trim: true)
  end

  defp response_buffer_exceeded?(response) do
    byte_size(response) > max_response_buffer_bytes()
  end

  defp max_response_buffer_bytes do
    Application.get_env(
      :boruta_gateway,
      :max_response_buffer_bytes,
      @default_max_response_buffer_bytes
    )
  end

  defp log_completed_exchange(%State{start: nil}), do: :ok

  defp log_completed_exchange(%State{} = state) do
    status = state.response && status_code(state.response)

    log_exchange(
      state,
      state.start,
      state.request_id,
      state.method,
      state.path,
      state.upstream,
      status,
      :success
    )
  end

  defp log_exchange(_state, _start, _request_id, _method, _path, _upstream, nil, _status), do: :ok

  defp log_exchange(state, start, request_id, method, path, upstream, status, business_status) do
    stop = :os.system_time(:microsecond)
    request_time = stop - start
    upstream_time = upstream_time(state, stop)

    :telemetry.execute(
      [:boruta_gateway, :request, :stop],
      %{duration: request_time},
      %{
        request_id: request_id,
        method: method,
        path: path,
        status: status,
        remote_ip: state.remote_ip || remote_ip(state.socket),
        tls: downstream_tls(state.socket)
      }
    )

    :telemetry.execute(
      [:boruta_gateway, :proxy, business_status],
      %{
        request_time: request_time,
        gateway_time: request_time - upstream_time,
        upstream_time: upstream_time
      },
      %{
        request_id: request_id,
        upstream: upstream,
        upstream_tls: upstream_tls(upstream)
      }
    )
  end

  defp upstream_time(%State{upstream_start: nil}, _stop), do: 0
  defp upstream_time(%State{upstream_start: upstream_start}, stop), do: stop - upstream_start

  defp downstream_tls(nil), do: nil

  defp downstream_tls(socket) do
    case :ssl.peercert(socket) do
      {:ok, _certificate} -> "mtls"
      {:error, _reason} -> "tls"
    end
  end

  defp upstream_tls(%Upstream{scheme: "https", mtls_enabled: true}), do: "mtls"
  defp upstream_tls(%Upstream{scheme: "https"}), do: "tls"
  defp upstream_tls(%Upstream{}), do: "http"
  defp upstream_tls(nil), do: nil

  defp transform_header(payload, upstream, nil) do
    transform_header(payload, upstream, false)
  end

  defp transform_header(payload, upstream, preserve_forwarded_authorization?)
       when is_boolean(preserve_forwarded_authorization?) do
    [_, _method, path] =
      Regex.run(~r{^(GET|POST|PUT|PATCH|OPTIONS|DELETE|HEAD) ([^\s]+)}, payload)

    upstream_path =
      case upstream do
        %Upstream{strip_uri: true, uris: uris} ->
          strip_upstream_path(path, uris)

        %Upstream{strip_uri: false} ->
          path
      end

    payload = replace_request_target(payload, upstream_path)

    payload
    |> clean_request_headers(preserve_forwarded_authorization?)
    |> put_header("Host", upstream_host_header(upstream))
  end

  defp transform_header(payload, upstream, token) do
    claims = %{
      "scope" => token.scope,
      "sub" => token.sub,
      "value" => token.value,
      "exp" => token.expires_at,
      "client_id" => token.client && token.client.id,
      "iat" => token.inserted_at && DateTime.to_unix(token.inserted_at)
    }

    jwt =
      with %Joken.Signer{} = signer <- signer(upstream),
           {:ok, jwt, _claims} <- Token.encode_and_sign(claims, signer) do
        jwt
      else
        _ -> nil
      end

    payload =
      Regex.replace(
        ~r{(^|\r\n)authorization\s*:\s*([^\r\n]+)\r\n}i,
        payload,
        "\\1Authorization: bearer #{jwt}\r\nX-Forwarded-Authorization: \\2\r\n"
      )

    transform_header(payload, upstream, true)
  end

  defp strip_upstream_path(path, uris) do
    uris
    |> Enum.sort_by(&byte_size/1, :desc)
    |> Enum.find(fn uri -> upstream_uri_matches_path?(uri, path) end)
    |> case do
      nil ->
        path

      "/" ->
        path

      uri ->
        String.replace_prefix(path, uri, "")
    end
    |> normalize_upstream_path()
  end

  defp upstream_uri_matches_path?("/", _path), do: true

  defp upstream_uri_matches_path?(uri, path) do
    path == uri ||
      String.starts_with?(path, uri <> "/") ||
      String.starts_with?(path, uri <> "?")
  end

  defp normalize_upstream_path(""), do: "/"
  defp normalize_upstream_path("?" <> query), do: "/?" <> query
  defp normalize_upstream_path(path), do: path

  defp upstream_host_header(%Upstream{virtual_host: virtual_host}) when is_binary(virtual_host),
    do: virtual_host

  defp upstream_host_header(%Upstream{host: host}), do: host

  defp replace_request_target(payload, upstream_path) do
    case String.split(payload, "\r\n", parts: 2) do
      [request_line, rest] ->
        replace_request_line_target(request_line, upstream_path) <> "\r\n" <> rest

      [request_line] ->
        replace_request_line_target(request_line, upstream_path)
    end
  end

  defp replace_request_line_target(request_line, upstream_path) do
    case String.split(request_line, " ", parts: 3) do
      [method, _path, version] -> Enum.join([method, upstream_path, version], " ")
      _ -> request_line
    end
  end

  defp clean_request_headers(payload, preserve_forwarded_authorization?) do
    rejected_headers = [
      "connection",
      "expect",
      "host",
      "keep-alive",
      "proxy-authenticate",
      "proxy-authorization",
      "te",
      "trailer",
      "upgrade"
    ]

    rejected_headers =
      case preserve_forwarded_authorization? do
        true -> rejected_headers
        false -> ["x-forwarded-authorization" | rejected_headers]
      end

    reject_headers(payload, rejected_headers)
  end

  defp clean_response_headers(header) do
    reject_header_lines(header, [
      "connection",
      "keep-alive",
      "proxy-authenticate",
      "proxy-authorization",
      "strict-transport-security",
      "te",
      "trailer",
      "upgrade"
    ])
  end

  defp reject_headers(payload, rejected_headers) do
    case split_headers(payload) do
      {:ok, header, body} ->
        reject_header_lines(header, rejected_headers) <> "\r\n\r\n" <> body

      :error ->
        payload
    end
  end

  defp reject_header_lines(header, rejected_headers) do
    header
    |> String.split("\r\n")
    |> Enum.with_index()
    |> Enum.reject(fn
      {_line, 0} ->
        false

      {line, _index} ->
        header_name(line) in rejected_headers
    end)
    |> Enum.map_join("\r\n", fn {line, _index} -> line end)
  end

  defp put_header(payload, header_name, header_value) do
    case split_headers(payload) do
      {:ok, header, body} ->
        header <> "\r\n" <> header_name <> ": " <> header_value <> "\r\n\r\n" <> body

      :error ->
        payload
    end
  end

  defp header_name(header_line) do
    header_line
    |> String.split(":", parts: 2)
    |> List.first()
    |> String.downcase()
  end

  def signer(
        %Upstream{
          forwarded_token_signature_alg: signature_alg,
          forwarded_token_secret: secret,
          forwarded_token_private_key: private_key
        } = upstream
      ) do
    case signature_alg && signature_type(upstream) do
      :symmetric ->
        Joken.Signer.create(signature_alg, secret)

      :asymmetric ->
        Joken.Signer.create(signature_alg, %{"pem" => private_key})

      nil ->
        nil
    end
  end

  defp signature_type(%Upstream{forwarded_token_signature_alg: signature_alg}) do
    case signature_alg && String.match?(signature_alg, ~r/HS/) do
      true -> :symmetric
      false -> :asymmetric
      nil -> nil
    end
  end

  defp message_complete?(response) do
    case split_headers(response) do
      :error ->
        false

      {:ok, header, body} ->
        status_code = status_code(header)
        headers = response_headers(header)

        response_body_complete?(status_code, headers, body)
    end
  end

  defp response_body_complete?(status_code, headers, body) do
    cond do
      bodyless_status?(status_code) ->
        true

      chunked_response?(headers) ->
        chunked_body_complete?(body)

      content_length = headers["content-length"] ->
        content_length_complete?(body, content_length)

      true ->
        false
    end
  end

  defp content_length_complete?(body, content_length) do
    case Integer.parse(content_length) do
      {length, ""} when length >= 0 -> byte_size(body) >= length
      _invalid_content_length -> false
    end
  end

  defp status_code(header) do
    case Regex.run(~r/^HTTP\/\d(?:\.\d)?\s+(\d{3})/, header) do
      [_status_line, status_code] -> String.to_integer(status_code)
      nil -> nil
    end
  end

  defp response_headers(header) do
    header
    |> String.split("\r\n")
    |> Enum.drop(1)
    |> Enum.reduce(%{}, fn header, headers ->
      case String.split(header, ":", parts: 2) do
        [name, value] -> Map.put(headers, String.downcase(name), String.trim(value))
        _ -> headers
      end
    end)
  end

  defp split_headers(payload) do
    case String.split(payload, "\r\n\r\n", parts: 2) do
      [header, body] -> {:ok, header, body}
      [_partial_header] -> :error
    end
  end

  defp bodyless_status?(status_code) when status_code in [204, 304], do: true
  defp bodyless_status?(status_code) when status_code in 100..199, do: true
  defp bodyless_status?(_status_code), do: false

  defp chunked_response?(headers) do
    headers
    |> Map.get("transfer-encoding", "")
    |> String.downcase()
    |> String.contains?("chunked")
  end

  defp chunked_body_complete?(body) do
    case Regex.run(~r/(?:^|\r\n)0\r\n/s, body, return: :index) do
      [{start, length}] ->
        trailer_start = start + length
        String.slice(body, trailer_start..-1//1) |> String.contains?("\r\n")

      nil ->
        false
    end
  end
end
