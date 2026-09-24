defmodule BorutaGateway.UpstreamConnection do
  @moduledoc false

  alias BorutaGateway.Certificate
  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Record
  alias BorutaGateway.Upstreams.Upstream

  @connect_timeout 5_000

  @type transport :: :tcp | :ssl
  @type route :: :direct | :proxy

  @spec connect(Upstream.t()) ::
          {:ok, :gen_tcp.socket() | :ssl.sslsocket(), transport(), route()}
          | {:error, term()}
  def connect(%Upstream{proxy_url: proxy_url} = upstream)
      when proxy_url in [nil, ""] do
    connect_direct(upstream)
  end

  def connect(%Upstream{} = upstream) do
    case find_proxy(upstream.proxy_url) do
      {:ok, record, service} ->
        connect_through_proxy(record.ip_address, service["port"], record.node_name)

      {:error, :proxy_not_found} ->
        connect_external_proxy(upstream.proxy_url)
    end
  end

  @spec prepare_request(binary(), Upstream.t(), route()) :: binary()
  def prepare_request(payload, %Upstream{}, :direct), do: payload

  def prepare_request(payload, %Upstream{} = upstream, :proxy) do
    Regex.replace(
      ~r/^([A-Z]+) ([^\s]+) (HTTP\/\d\.\d)/,
      payload,
      fn _request_line, method, target, version ->
        "#{method} #{absolute_target(upstream, target)} #{version}"
      end
    )
  end

  defp connect_direct(%Upstream{scheme: "http"} = upstream) do
    case :gen_tcp.connect(
           String.to_charlist(upstream.host),
           upstream.port,
           socket_options(),
           @connect_timeout
         ) do
      {:ok, socket} -> {:ok, socket, :tcp, :direct}
      {:error, error} -> {:error, error}
    end
  end

  defp connect_direct(%Upstream{scheme: "https"} = upstream) do
    case :ssl.connect(
           String.to_charlist(upstream.host),
           upstream.port,
           target_ssl_options(upstream),
           @connect_timeout
         ) do
      {:ok, socket} -> {:ok, socket, :ssl, :direct}
      {:error, error} -> {:error, error}
    end
  end

  defp find_proxy(proxy_url) do
    ServiceRegistry.list_records()
    |> Enum.find_value(fn record ->
      if record.status == "online" do
        case https_proxy_service(record) do
          nil -> nil
          service -> if proxy_url(record, service) == proxy_url, do: {record, service}
        end
      end
    end)
    |> case do
      nil ->
        {:error, :proxy_not_found}

      {%Record{} = record, service} ->
        {:ok, record, service}
    end
  end

  defp https_proxy_service(%Record{configuration: configuration}) do
    configuration
    |> Map.get("services", [])
    |> Enum.find(fn service ->
      service["type"] == "proxy" && service["scheme"] == "https" && service["enabled"] == true &&
        is_integer(service["port"])
    end)
  end

  defp connect_external_proxy(proxy_url) do
    case URI.parse(proxy_url) do
      %URI{scheme: "https", host: host, port: port} when is_binary(host) and is_integer(port) ->
        connect_through_proxy(host, port, host)

      _ ->
        {:error, :invalid_proxy_url}
    end
  end

  defp connect_through_proxy(host, port, verification_host) do
    case :ssl.connect(
           String.to_charlist(host),
           port,
           proxy_ssl_options(verification_host),
           @connect_timeout
         ) do
      {:ok, socket} -> {:ok, socket, :ssl, :proxy}
      {:error, error} -> {:error, error}
    end
  end

  defp proxy_url(%Record{} = record, service) do
    "https://#{authority(record.ip_address, service["port"])}"
  end

  defp socket_options do
    [:binary, {:packet, :raw}, {:active, false}]
  end

  defp target_ssl_options(%Upstream{} = upstream) do
    socket_options() ++
      peer_verification_options(upstream.host, Certificate.gateway_cacerts()) ++
      mtls_options(upstream)
  end

  defp proxy_ssl_options(verification_host) do
    socket_options() ++
      peer_verification_options(verification_host, Certificate.gateway_cacerts()) ++
      Certificate.ssl_options()
  end

  defp peer_verification_options(host, cacerts) do
    hostname = String.to_charlist(host)

    [
      {:verify, :verify_peer},
      {:server_name_indication, hostname},
      {:customize_hostname_check, [fqdn: hostname]},
      {:cacerts, cacerts}
    ]
  end

  defp mtls_options(%Upstream{mtls_enabled: true}), do: Certificate.ssl_options()
  defp mtls_options(%Upstream{}), do: []

  defp absolute_target(%Upstream{} = upstream, target) do
    path = origin_form(target)
    "#{upstream.scheme}://#{authority(upstream.host, upstream.port)}#{path}"
  end

  defp origin_form(target) do
    case URI.parse(target) do
      %URI{scheme: nil} ->
        target

      %URI{} = uri ->
        path = uri.path || "/"
        if uri.query, do: "#{path}?#{uri.query}", else: path
    end
  end

  defp authority(host, port) do
    host = if String.contains?(host, ":"), do: "[#{host}]", else: host
    "#{host}:#{port}"
  end
end
