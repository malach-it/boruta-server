defmodule BorutaGateway.HttpProxy.Handler do
  import Plug.Conn

  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.NodeConnection

  def init(options), do: options

  def call(conn, _options) do
    dbg(conn)
    current_node = ServiceRegistry.current_node()

    {host, port} =
      case Enum.find(current_node.connections, fn %NodeConnection{to: to} ->
             to.name == conn.host
           end) do
        %NodeConnection{to: target, status: _status} ->
          # TODO configurable sidecar port
          {target.ip, Application.get_env(:boruta_gateway, :sidecar_port)}
          # TODO circuit breaker if status is not up

        _ ->
          {conn.host, 80}
      end

    method = conn.method

    url =
      %URI{scheme: "http", host: host, path: conn.request_path, query: conn.query_string, port: port}
      |> URI.to_string()

    headers =
      conn.req_headers
      |> Enum.reject(fn
        {"x-forwarded-authorization", _value} -> true
        {"connection", _value} -> true
        {"content-length", _value} -> true
        {"expect", _value} -> true
        {"host", _value} -> true
        {"keep-alive", _value} -> true
        {"transfer-encoding", _value} -> true
        {"upgrade", _value} -> true
        _rest -> false
      end)

    # TODO read body in case of chunked body
    body =
      case Plug.Conn.read_body(conn) do
        {:ok, body} -> body
        _ -> ""
      end

    case Finch.build(method, url, headers, body) |> Finch.request(HttpProxyClient) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        conn =
          Enum.reduce(headers, conn, fn
            {"connection", _value}, conn -> conn
            {"strict-transport-security", _value}, conn -> conn
            {"host", _value}, conn -> put_resp_header(conn, "host", conn.host)
            {key, value}, conn -> put_resp_header(conn, String.downcase(key), value)
          end)

        send_resp(conn, status, body)
        |> halt()

      {:error, error} ->
        send_resp(conn, 500, inspect(error))
        |> halt()
    end
  end
end
