defmodule BorutaGateway.Upstreams.Client do
  @moduledoc """
  Upstream scoped HTTP client
  """

  use GenServer

  import Plug.Conn

  alias BorutaGateway.Upstreams.Upstream

  def child_spec(upstream) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [upstream]},
      type: :worker,
      restart: :transient
    }
  end

  def name(%Upstream{id: upstream_id}) when is_binary(upstream_id) do
    "gateway_client_#{upstream_id}" |> String.replace("-", "") |> String.to_atom()
  end

  def finch_name(%Upstream{id: upstream_id}) when is_binary(upstream_id) do
    "finch_gateway_client_#{upstream_id}" |> String.replace("-", "") |> String.to_atom()
  end

  def start_link(upstream) do
    GenServer.start_link(__MODULE__, upstream, name: name(upstream))
  end

  def init(upstream) do
    name = finch_name(upstream)
    {:ok, _pid} =
      Finch.start_link(
        name: name,
        pools: %{
          :default => [size: upstream.pool_size, count: upstream.pool_count]
        },
        conn_max_idle_time: upstream.max_idle_time
      )

    {:ok, %{upstream: upstream, http_client: name}}
  end

  def upstream(client) do
    GenServer.call(client, {:get, :upstream})
  end

  def http_client(client) do
    GenServer.call(client, {:get, :http_client})
  end

  def request(%Upstream{http_client: http_client} = upstream, conn) do
    http_client = http_client(http_client)

    Finch.build(
      transform_method(conn),
      transform_url(upstream, conn),
      transform_headers(conn),
      transform_body(conn)
    )
    |> Finch.request(http_client)
  end

  def handle_call({:get, :upstream}, _from, %{upstream: upstream} = state) do
    {:reply, upstream, state}
  end

  def handle_call({:get, :http_client}, _from, %{http_client: http_client} = state) do
    {:reply, http_client, state}
  end

  defp transform_method(%Plug.Conn{method: method}) do
    method |> String.downcase() |> String.to_atom()
  end

  defp transform_headers(%{req_headers: req_headers}) do
    Enum.reject(req_headers, fn
      {"connection", _value} -> true
      {"content-length", _value} -> true
      {"expect", _value} -> true
      {"host", _value} -> true
      {"keep-alive", _value} -> true
      {"transfer-encoding", _value} -> true
      {"upgrade", _value} -> true
      _rest -> false
    end)
  end

  defp transform_body(conn) do
    case read_body(conn) do
      {:ok, body, _conn} -> body
      _ -> ""
    end
  end

  defp transform_url(
         %Upstream{scheme: scheme, host: host, port: port, uris: uris, strip_uri: strip_uri},
         %Plug.Conn{request_path: request_path} = conn
       ) do
    path =
      case strip_uri do
        true ->
          matching_uri = Enum.find(uris, fn uri -> String.starts_with?(request_path, uri) end)
          String.replace_prefix(request_path, matching_uri, "")

        false ->
          request_path
      end

    conn = fetch_query_params(conn)
    query = URI.encode_query(conn.query_params)

    uri = %URI{authority: host, host: host, path: path, port: port, query: query, scheme: scheme}
    URI.to_string(uri)
  end
end
