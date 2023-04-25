defmodule BorutaGateway.Upstreams.Client do
  @moduledoc """
  Upstream scoped HTTP client
  """

  use GenServer

  import Plug.Conn

  alias Boruta.Oauth
  alias BorutaGateway.Upstreams.Upstream

  defmodule Token do
    @moduledoc false

    use Joken.Config

    def token_config, do: %{}
  end

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

  @impl GenServer
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
      transform_headers(upstream, conn),
      transform_body(conn)
    )
    |> Finch.request(http_client)
  end

  @impl GenServer
  def handle_call({:get, :upstream}, _from, %{upstream: upstream} = state) do
    {:reply, upstream, state}
  end

  def handle_call({:get, :http_client}, _from, %{http_client: http_client} = state) do
    {:reply, http_client, state}
  end

  defp transform_method(%Plug.Conn{method: method}) do
    method |> String.downcase() |> String.to_atom()
  end

  defp transform_headers(
         upstream,
         %Plug.Conn{req_headers: req_headers} = conn
       ) do
    authorization_header =
      case get_req_header(conn, "authorization") do
        [] -> ""
        [authorization] -> authorization
      end

    token = conn.assigns[:token] || %Oauth.Token{type: "access_token"}

    payload = %{
      "scope" => token.scope,
      "sub" => token.sub,
      "value" => token.value,
      "exp" => token.expires_at,
      "client_id" => token.client && token.client.id,
      "iat" => token.inserted_at && DateTime.to_unix(token.inserted_at)
    }

    token =
      with %Joken.Signer{} = signer <- signer(upstream),
           {:ok, token, _payload} <- Token.encode_and_sign(payload, signer) do
        token
      else
        _ -> nil
      end

    req_headers
    |> List.insert_at(0, {"x-forwarded-authorization", authorization_header})
    |> Enum.reject(fn
      {"authorization", _value} -> true
      {"connection", _value} -> true
      {"content-length", _value} -> true
      {"expect", _value} -> true
      {"host", _value} -> true
      {"keep-alive", _value} -> true
      {"transfer-encoding", _value} -> true
      {"upgrade", _value} -> true
      _rest -> false
    end)
    |> List.insert_at(0, {"authorization", "bearer #{token}"})
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
          case matching_uri == "/" do
            true -> request_path
            false -> String.replace_prefix(request_path, matching_uri, "")
          end

        false ->
          request_path
      end

    conn = fetch_query_params(conn)
    query = URI.encode_query(conn.query_params)

    uri = %URI{authority: host, host: host, path: path, port: port, query: query, scheme: scheme}
    URI.to_string(uri)
  end
end
