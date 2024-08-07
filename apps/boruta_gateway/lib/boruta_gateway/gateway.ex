defmodule BorutaGateway.Gateway do
  @moduledoc false

  use GenServer

  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  @connect_timeout 5_000

  def start(args) do
    {:ok, listen_socket} =
      :gen_tcp.listen(args[:port], [{:packet, :raw}, :binary, {:active, false}])

    children =
      Enum.map(1..args[:num_acceptors], fn i ->
        Supervisor.child_spec({__MODULE__, %{listen_socket: listen_socket}},
          id: :"gateway_server_acceptor_#{i}"
        )
      end)

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  defmodule State do
    @moduledoc false

    defstruct [:listen_socket, :socket, :client_socket, :start]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    Process.flag(:trap_exit, true)
    listen_socket = args[:listen_socket]

    send(self(), :accept)

    {:ok, %State{listen_socket: listen_socket}}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    :gen_tcp.close(state.listen_socket)
    {:stop, reason, state}
  end

  def handle_info(:accept, state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)

    :inet.setopts(socket, active: :once)

    {:noreply, %{state | socket: socket, client_socket: nil}}
  end

  def handle_info({:tcp_closed, socket}, %State{socket: socket} = state) do
    request_time = :os.system_time(:microsecond) - state.start |> dbg

    :gen_tcp.close(socket)
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)
    :inet.setopts(socket, active: :once)

    {:noreply, %{state | socket: socket, client_socket: nil}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state}
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket, client_socket: nil} = state) do
    start = :os.system_time(:microsecond)
    [_, host] = Regex.run(~r{[H|h]ost\: ([^\r]+)}, payload)
    [_, authorization] = Regex.run(~r{[A|a]uthorization\: ([^\r]+)}, payload) || [nil, nil]
    [_, method, relative_path] = Regex.run(~r{^(\w+)\s\/([^\s]+)}, payload)

    with %Upstream{scheme: scheme, host: target, port: port, uris: uris, strip_uri: strip_uri} =
           upstream <-
           Upstreams.sidecar_match(String.split(relative_path, "/")),
         :ok <- check_authorization(upstream, method, authorization) do
      case scheme do
        "http" ->
          case :gen_tcp.connect(
                 String.to_charlist(target),
                 port || 80,
                 [:binary, {:packet, :raw}, {:active, false}],
                 @connect_timeout
               ) do
            {:ok, client_socket} ->
              connect_time = :os.system_time(:microsecond) - start |> dbg
              payload = String.replace(payload, host, target)

              payload =
                case strip_uri do
                  true ->
                    Enum.reduce(uris, payload, fn prefix, payload ->
                      String.replace(payload, prefix, "")
                    end)

                  _ ->
                    payload
                end

              :ok = :gen_tcp.send(client_socket, payload)

              :inet.setopts(socket, active: :once)
              :inet.setopts(client_socket, active: :once)
              {:noreply, %{state | client_socket: client_socket, start: start}}
          end

        "https" ->
          nil
          # open an ssl connection
      end
    else
      # TODO close client socket in case of failure
      :forbidden ->
        :gen_tcp.send(socket, "HTTP/1.1 403 Forbidden\r\n\r\n")
        :gen_tcp.close(socket)
        request_duration = :os.system_time(:microsecond) - start

        {:noreply, state}

      :unauthorized ->
        :gen_tcp.send(socket, "HTTP/1.1 401 Unauthorized\r\n\r\n")
        :gen_tcp.close(socket)
        request_duration = :os.system_time(:microsecond) - start

        {:noreply, state}

      nil ->
        :gen_tcp.send(socket, "HTTP/1.1 404 Not Found\r\n\r\n")
        :gen_tcp.close(socket)
        request_duration = :os.system_time(:microsecond) - start

        {:noreply, state}
    end
  end

  def handle_info({:tcp, socket, payload}, %State{client_socket: socket} = state) do
    :inet.setopts(socket, active: :once)
    :gen_tcp.send(state.socket, payload)
    {:noreply, state}
  end

  def handle_info({:tcp, socket, payload}, %State{socket: socket} = state) do
    :inet.setopts(socket, active: :once)
    :gen_tcp.send(state.client_socket, payload)
    {:noreply, state}
  end

  def handle_info(info, state) do
    dbg(info)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    state.client_socket && :gen_tcp.close(state.client_socket)
    state.socket && :gen_tcp.close(state.socket)
    :gen_tcp.close(state.listen_socket)
    {:stop, reason}
  end

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token

  defp check_authorization(
         %Upstream{authorize: true},
         _method,
         nil
       ) do
    :unauthorized
  end

  defp check_authorization(
         %Upstream{authorize: true, required_scopes: required_scopes},
         method,
         authorization
       ) do

    with [_header, value] <- Regex.run(~r/[B|b]earer (.+)/, authorization),
         {:ok, %Token{scope: scope}} <- Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, required_scopes, method) do
      :ok
    else
      {:error, "required scopes are not present."} ->
        :forbidden

      _error ->
        :unauthorized
    end
  end

  defp check_authorization(_upstream, _method, _authorization), do: :ok

  defp validate_scopes(_scope, required_scopes, _method) when required_scopes == %{},
    do: {:ok, []}

  defp validate_scopes(scope, required_scopes, method) do
    scopes = Scope.split(scope)
    default_scopes = Map.get(required_scopes, "*", [:not_authorized])

    case Enum.empty?(Map.get(required_scopes, method, default_scopes) -- scopes) do
      true -> {:ok, scopes}
      false -> {:error, "required scopes are not present."}
    end
  end
end
