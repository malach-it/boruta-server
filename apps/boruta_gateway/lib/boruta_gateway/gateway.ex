defmodule BorutaGateway.Gateway do
  @moduledoc false

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
  end

  use GenServer

  alias BorutaGateway.Gateway.Authorization
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  @connect_timeout 5_000

  defmodule Server do
    use GenServer

    alias BorutaGateway.Gateway

    def start(args) do
      GenServer.start_link(__MODULE__, args)
    end

    @impl GenServer
    def init(args) do
      {:ok, listen_socket} =
        :gen_tcp.listen(args[:port], [
          {:packet, :raw},
          :binary,
          {:active, false},
          {:reuseaddr, true}
        ])

      children =
        Enum.map(1..args[:num_acceptors], fn i ->
          Supervisor.child_spec(
            {Gateway,
             [
               listen_socket: listen_socket,
               match_function: args[:match_function]
             ]},
            id: :"http_proxy_server_acceptor_#{i}"
          )
        end)

      Process.flag(:trap_exit, true)

      with {:ok, supervisor} <- Supervisor.start_link(children, strategy: :one_for_one) do
        {:ok, supervisor: supervisor, listen_socket: listen_socket}
      end
    end

    @impl GenServer
    def handle_info({:EXIT, _pid, reason}, state) do
      :gen_tcp.close(state[:listen_socket])

      {:stop, reason, state}
    end

    @impl GenServer
    def terminate(_reason, state) do
      :gen_tcp.close(state[:listen_socket])

      :ok
    end
  end

  defmodule State do
    @moduledoc false

    defstruct [
      :listen_socket,
      :match_function,
      :socket,
      :client_socket,
      :start,
      :request,
      :response,
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
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        :inet.setopts(socket, active: :once)

        {:noreply, %{state | socket: socket, client_socket: nil, response: nil}}

      {:error, _error} ->
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:tcp_closed, socket}, %State{socket: socket} = state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)
    :inet.setopts(socket, active: :once)

    {:noreply, %{state | socket: socket, client_socket: nil, response: nil}}
  end

  def handle_info({:tcp_closed, socket}, %State{client_socket: socket} = state) do
    {:noreply, close_exchange(state, socket, :tcp)}
  end

  def handle_info({:ssl_closed, socket}, %State{client_socket: socket} = state) do
    {:noreply, close_exchange(state, socket, :ssl)}
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket, client_socket: nil} = state) do
    start = :os.system_time(:microsecond)
    [_, method, path] = Regex.run(~r{^(GET|POST|PUT|PATCH|OPTIONS|DELETE) ([^\s]+)}, payload)
    # [_, host] = Regex.run(~r{[H|h]ost\: ([^\r]+)}, payload)

    path_info = String.split(path, "/", trim: true)

    with %Upstream{} = upstream <- state.match_function.(path_info),
         {:ok, token} <- Authorization.authorize(payload, method, upstream) do
      _connect = :os.system_time(:microsecond) - start

      case upstream.scheme do
        "http" ->
          case :gen_tcp.connect(
                 upstream.host |> String.to_charlist(),
                 upstream.port,
                 [:binary, {:packet, :raw}, {:active, false}],
                 @connect_timeout
               ) do
            {:ok, client_socket} ->
              _connected = :os.system_time(:microsecond) - start
              :ok = :gen_tcp.send(client_socket, transform_header(payload, upstream, token))

              :inet.setopts(socket, active: :once)
              :inet.setopts(client_socket, active: :once)
              {:noreply, %{state | client_socket: client_socket, start: start}}

            {:error, _error} ->
              :gen_tcp.send(socket, "HTTP/1.1 503 Service Unavailable\r\n\r\n")

              {:noreply, close_downstream(socket, state)}
          end

        "https" ->
          case :ssl.connect(
                 upstream.host |> String.to_charlist(),
                 upstream.port,
                 [
                   :binary,
                   {:packet, :raw},
                   {:active, false},
                   {:verify, :verify_peer},
                   {:cacerts, :public_key.cacerts_get()}
                 ],
                 @connect_timeout
               ) do
            {:ok, client_socket} ->
              _connected = :os.system_time(:microsecond) - start
              :ok = :ssl.send(client_socket, transform_header(payload, upstream, token))

              :inet.setopts(socket, active: :once)
              :ssl.setopts(client_socket, active: :once)
              {:noreply, %{state | client_socket: client_socket, start: start}}

            {:error, _error} ->
              :gen_tcp.send(socket, "HTTP/1.1 503 Service Unavailable\r\n\r\n")

              {:noreply, close_downstream(socket, state)}
          end
      end
    else
      # TODO close client socket in case of failure
      nil ->
        response = "No upstream has been found corresponding to the given request."

        :gen_tcp.send(
          socket,
          "HTTP/1.1 404 Not Found\r\n" <>
            "Content-Length: 62\r\n\r\n" <>
            response
        )

        _response = :os.system_time(:microsecond) - start

        {:noreply, close_downstream(socket, state)}

      {:unauthorized, content_type, response} ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 401 Unauthorized\r\n" <>
            "Content-Type: #{content_type}\r\n" <>
            "Content-Length: #{byte_size(response)}\r\n\r\n" <>
            response
        )

        _response = :os.system_time(:microsecond) - start

        {:noreply, close_downstream(socket, state)}

      {:forbidden, content_type, response} ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 403 Forbidden\r\n" <>
            "Content-Type: #{content_type}\r\n" <>
            "Content-Length: #{byte_size(response)}\r\n\r\n" <>
            response
        )

        _response = :os.system_time(:microsecond) - start

        {:noreply, close_downstream(socket, state)}
    end
  end

  def handle_info({:tcp, socket, payload}, %State{client_socket: socket} = state) do
    # TODO clean response headers (connection, strict-transport-security)
    # clean_response_headers(payload)
    response = (state.response || "") <> payload

    :gen_tcp.send(state.socket, payload)

    case message_complete?(response) do
      true ->
        {:noreply, close_exchange(state, socket, :tcp)}

      false ->
        :inet.setopts(socket, active: :once)
        {:noreply, %{state | response: response}}
    end
  end

  def handle_info({:ssl, socket, payload}, %State{client_socket: socket} = state) do
    # TODO clean response headers (connection, strict-transport-security)
    # clean_response_headers(payload)
    response = (state.response || "") <> payload
    :gen_tcp.send(state.socket, payload)

    case message_complete?(response) do
      true ->
        {:noreply, close_exchange(state, socket, :ssl)}

      false ->
        :ssl.setopts(socket, active: :once)
        {:noreply, %{state | response: response}}
    end
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket} = state) do
    :inet.setopts(socket, active: :once)

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

  @impl GenServer
  def terminate(reason, _state) do
    {:stop, reason}
  end

  defp close_downstream(socket, state) do
    :gen_tcp.close(socket)
    send(self(), :accept)

    %{state | socket: nil, client_socket: nil, request: nil, response: nil}
  end

  defp close_exchange(state, upstream_socket, :tcp) do
    :gen_tcp.close(state.socket)
    :gen_tcp.close(upstream_socket)
    send(self(), :accept)

    %{state | socket: nil, client_socket: nil, request: nil, response: nil}
  end

  defp close_exchange(state, upstream_socket, :ssl) do
    :gen_tcp.close(state.socket)
    :ssl.close(upstream_socket)
    send(self(), :accept)

    %{state | socket: nil, client_socket: nil, request: nil, response: nil}
  end

  defp transform_header(payload, upstream, nil) do
    [_, _method, path] =
      Regex.run(~r{^(GET|POST|PUT|PATCH|OPTIONS|DELETE) ([^\s]+)}, payload)

    upstream_path =
      case upstream do
        %Upstream{strip_uri: true, uris: uris} ->
          Enum.reduce(uris, path, fn
            "/", _ ->
              path

            uri, path ->
              String.replace_prefix(path, uri, "")
          end)

        %Upstream{strip_uri: false} ->
          path
      end

    # TODO clean request headers
    # (x-forwarded-authorization, connection, content-length, expect, host, keep-alive, transfer-encoding, upgrade)
    # clean_request_headers(payload)

    [_, _method, path] = Regex.run(~r{^(GET|POST|PUT|PATCH|OPTIONS|DELETE) ([^\s]+)}, payload)
    [_, host] = Regex.run(~r{[H|h]ost\: ([^\r]+)}, payload)
    payload = String.replace(payload, path, upstream_path)
    String.replace(payload, host, upstream.host)
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
        ~r{[A|a]uthorization: ([^\r]+)\r\n},
        payload,
        "Authorization: bearer #{jwt}\r\nX-Forwarded-Authorization: \\1\r\n"
      )

    transform_header(payload, upstream, nil)
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
    case String.split(response, "\r\n\r\n") do
      [_partial_header] ->
        false

      [header, body] ->
        status_code = status_code(header)
        headers = response_headers(header)

        cond do
          bodyless_status?(status_code) ->
            true

          chunked_response?(headers) ->
            chunked_body_complete?(body)

          content_length = headers["content-length"] ->
            byte_size(body) >= String.to_integer(content_length)

          true ->
            false
        end

      [header | body_parts] ->
        status_code = status_code(header)
        headers = response_headers(header)
        body = Enum.join(body_parts, "\r\n\r\n")

        cond do
          bodyless_status?(status_code) ->
            true

          chunked_response?(headers) ->
            chunked_body_complete?(body)

          content_length = headers["content-length"] ->
            byte_size(body) >= String.to_integer(content_length)

          true ->
            false
        end
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
