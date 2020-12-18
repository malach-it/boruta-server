defmodule BorutaGateway.Upstreams.Client do
  @moduledoc false

  use GenServer

  import Plug.Conn

  alias BorutaGateway.Upstreams.Upstream

  @katipo_pool :katipo_pool

  def katipo_pool, do: @katipo_pool

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    :katipo_pool.start(@katipo_pool, opts[:pool_size], pipelining: :multiplex)

    {:ok, []}
  end

  # @spec request(conn :: %Plug.Conn{}) ::
  def request(%Upstream{} = upstream, %Plug.Conn{} = conn) do
    :katipo.req(:katipo_pool, %{
      method: transform_method(conn),
      headers: transform_headers(conn),
      body: transform_body(conn),
      url: transform_url(upstream, conn),
      return_metrics: true
    })
  end

  defp transform_method(%{method: method}) do
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

    uri = %URI{host: host, path: path, port: port, query: query, scheme: scheme}
    URI.to_string(uri)
  end
end
