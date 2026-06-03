defmodule BorutaGateway.Kubernetes.Client do
  @moduledoc false

  @service_account_path "/var/run/secrets/kubernetes.io/serviceaccount"

  def list_ingresses(opts \\ []) do
    request(resource_path("apis/networking.k8s.io/v1", "ingresses", opts), opts)
  end

  def list_services(opts \\ []) do
    request(resource_path("api/v1", "services", opts), opts)
  end

  def namespace do
    namespace_path()
    |> File.read()
    |> case do
      {:ok, namespace} -> String.trim(namespace)
      {:error, _reason} -> nil
    end
  end

  defp request(path, opts) do
    url = api_url(opts) <> path

    headers = [
      {~c"Authorization", String.to_charlist("Bearer " <> token(opts))},
      {~c"Accept", ~c"application/json"}
    ]

    case :httpc.request(:get, {String.to_charlist(url), headers}, http_options(opts),
           body_format: :binary
         ) do
      {:ok, {{_http_version, status, _reason}, _headers, body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, {{_http_version, status, reason}, _headers, body}} ->
        {:error, {:kubernetes_api_error, status, reason, body}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp resource_path(api_prefix, resource, opts) do
    case Keyword.get(opts, :namespace) do
      nil -> "/#{api_prefix}/#{resource}"
      "" -> "/#{api_prefix}/#{resource}"
      namespace -> "/#{api_prefix}/namespaces/#{namespace}/#{resource}"
    end
  end

  defp api_url(opts) do
    scheme = Keyword.get(opts, :scheme, "https")
    host = Keyword.get(opts, :host) || System.fetch_env!("KUBERNETES_SERVICE_HOST")
    port = Keyword.get(opts, :port) || System.get_env("KUBERNETES_SERVICE_PORT", "443")

    "#{scheme}://#{host}:#{port}"
  end

  defp token(opts) do
    case Keyword.get(opts, :token) do
      nil ->
        token_path()
        |> File.read!()
        |> String.trim()

      token ->
        token
    end
  end

  defp http_options(opts) do
    timeout = Keyword.get(opts, :timeout, 5_000)

    [
      ssl: ssl_options(opts),
      timeout: timeout
    ]
  end

  defp ssl_options(opts) do
    ca_cert_path = Keyword.get(opts, :ca_cert_path, ca_cert_path())

    if File.exists?(ca_cert_path) do
      server_name = api_server_name(opts)

      [
        verify: :verify_peer,
        cacertfile: String.to_charlist(ca_cert_path),
        server_name_indication: String.to_charlist(server_name),
        customize_hostname_check: [fqdn: String.to_charlist(server_name)]
      ]
    else
      [verify: :verify_none]
    end
  end

  defp api_server_name(opts) do
    Keyword.get(opts, :server_name) ||
      System.get_env("BORUTA_GATEWAY_KUBERNETES_API_SERVER_NAME") ||
      default_api_server_name(opts)
  end

  defp default_api_server_name(opts) do
    host = Keyword.get(opts, :host) || System.fetch_env!("KUBERNETES_SERVICE_HOST")

    if ip_address?(host) do
      "kubernetes.default.svc"
    else
      host
    end
  end

  defp ip_address?(host) do
    host
    |> String.to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, _address} -> true
      {:error, _reason} -> false
    end
  end

  defp token_path, do: Path.join(@service_account_path, "token")
  defp ca_cert_path, do: Path.join(@service_account_path, "ca.crt")
  defp namespace_path, do: Path.join(@service_account_path, "namespace")
end
