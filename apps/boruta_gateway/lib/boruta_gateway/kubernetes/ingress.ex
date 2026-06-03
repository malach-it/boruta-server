defmodule BorutaGateway.Kubernetes.Ingress do
  @moduledoc false

  @managed_by "kubernetes_ingress"

  def managed_by, do: @managed_by

  def desired_upstreams(ingresses, services, opts \\ []) do
    node_name = Keyword.get(opts, :node_name, "global")
    ingress_class = Keyword.get(opts, :ingress_class)
    services_by_key = services_by_key(services)

    ingresses
    |> Enum.filter(&matches_ingress_class?(&1, ingress_class))
    |> Enum.flat_map(&ingress_upstreams(&1, services_by_key, node_name))
    |> Enum.uniq_by(& &1.managed_id)
  end

  defp ingress_upstreams(ingress, services_by_key, node_name) do
    metadata = Map.get(ingress, "metadata", %{})
    spec = Map.get(ingress, "spec", %{})
    namespace = Map.get(metadata, "namespace", "default")
    ingress_name = Map.fetch!(metadata, "name")
    annotations = Map.get(metadata, "annotations", %{})
    scheme = backend_scheme(annotations)

    spec
    |> Map.get("rules", [])
    |> Enum.flat_map(fn rule ->
      host = blank_to_nil(Map.get(rule, "host"))

      rule
      |> get_in(["http", "paths"])
      |> List.wrap()
      |> Enum.flat_map(fn path ->
        path_upstream(
          path,
          namespace,
          ingress_name,
          host,
          scheme,
          node_name,
          services_by_key,
          annotations
        )
      end)
    end)
  end

  defp path_upstream(
         path,
         namespace,
         ingress_name,
         virtual_host,
         scheme,
         node_name,
         services_by_key,
         annotations
       ) do
    with %{"service" => service} <- Map.get(path, "backend"),
         service_name when is_binary(service_name) <- Map.get(service, "name"),
         service_port <- Map.get(service, "port", %{}),
         {:ok, port} <-
           resolve_service_port(services_by_key, namespace, service_name, service_port) do
      uri = path |> Map.get("path", "/") |> normalize_path()

      upstream = %{
        node_name: node_name,
        virtual_host: virtual_host,
        scheme: scheme,
        host: service_host(service_name, namespace),
        port: port,
        uris: [uri],
        authorize: false,
        required_scopes: %{},
        managed_id:
          managed_id(namespace, ingress_name, virtual_host, uri, service_name, service_port)
      }

      upstream =
        upstream
        |> put_boolean_annotation(annotations, :authorize, "boruta.patatoid.fr/authorize")
        |> put_map_annotation(annotations, :required_scopes, "boruta.patatoid.fr/required-scopes")
        |> put_string_annotation(
          annotations,
          :error_content_type,
          "boruta.patatoid.fr/error-content-type"
        )
        |> put_string_annotation(
          annotations,
          :forbidden_response,
          "boruta.patatoid.fr/forbidden-response"
        )
        |> put_string_annotation(
          annotations,
          :unauthorized_response,
          "boruta.patatoid.fr/unauthorized-response"
        )
        |> put_string_annotation(
          annotations,
          :forwarded_token_signature_alg,
          "boruta.patatoid.fr/forwarded-token-signature-alg"
        )
        |> put_string_annotation(
          annotations,
          :forwarded_token_secret,
          "boruta.patatoid.fr/forwarded-token-secret"
        )
        |> put_string_annotation(
          annotations,
          :forwarded_token_public_key,
          "boruta.patatoid.fr/forwarded-token-public-key"
        )
        |> put_string_annotation(
          annotations,
          :forwarded_token_private_key,
          "boruta.patatoid.fr/forwarded-token-private-key"
        )
        |> put_boolean_annotation(annotations, :mtls_enabled, "boruta.patatoid.fr/mtls-enabled")

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/strip-uri") do
          true ->
            Map.put(
              upstream,
              :strip_uri,
              truthy_annotation?(annotations, "boruta.patatoid.fr/strip-uri")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-enabled") do
          true ->
            Map.put(
              upstream,
              :rate_limit_enabled,
              truthy_annotation?(annotations, "boruta.patatoid.fr/rate-limit-enabled")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-count") do
          true ->
            Map.put(
              upstream,
              :rate_limit_count,
              integer_annotation(annotations, "boruta.patatoid.fr/rate-limit-count")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-time-unit") do
          true ->
            Map.put(
              upstream,
              :rate_limit_time_unit,
              string_annotation(annotations, "boruta.patatoid.fr/rate-limit-time-unit")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-penality") do
          true ->
            Map.put(
              upstream,
              :rate_limit_penality,
              integer_annotation(annotations, "boruta.patatoid.fr/rate-limit-penality")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-timeout") do
          true ->
            Map.put(
              upstream,
              :rate_limit_timeout,
              integer_annotation(annotations, "boruta.patatoid.fr/rate-limit-timeout")
            )

          false ->
            upstream
        end

      upstream =
        case Map.has_key?(annotations, "boruta.patatoid.fr/rate-limit-memory-length") do
          true ->
            Map.put(
              upstream,
              :rate_limit_memory_length,
              integer_annotation(annotations, "boruta.patatoid.fr/rate-limit-memory-length")
            )

          false ->
            upstream
        end

      [upstream]
    else
      _ -> []
    end
  end

  defp services_by_key(services) do
    services
    |> Enum.map(fn service ->
      metadata = Map.get(service, "metadata", %{})
      {{Map.get(metadata, "namespace", "default"), Map.get(metadata, "name")}, service}
    end)
    |> Enum.into(%{})
  end

  defp resolve_service_port(_services_by_key, _namespace, _service_name, %{"number" => port})
       when is_integer(port) do
    {:ok, port}
  end

  defp resolve_service_port(services_by_key, namespace, service_name, %{"name" => port_name}) do
    services_by_key
    |> Map.get({namespace, service_name}, %{})
    |> get_in(["spec", "ports"])
    |> List.wrap()
    |> Enum.find(fn port -> Map.get(port, "name") == port_name end)
    |> case do
      %{"port" => port} when is_integer(port) -> {:ok, port}
      _ -> :error
    end
  end

  defp resolve_service_port(_services_by_key, _namespace, _service_name, _service_port),
    do: :error

  defp matches_ingress_class?(_ingress, nil), do: true
  defp matches_ingress_class?(_ingress, ""), do: true

  defp matches_ingress_class?(ingress, ingress_class) do
    annotations = ingress |> Map.get("metadata", %{}) |> Map.get("annotations", %{})

    get_in(ingress, ["spec", "ingressClassName"]) == ingress_class ||
      Map.get(annotations, "kubernetes.io/ingress.class") == ingress_class
  end

  defp backend_scheme(annotations) do
    annotations
    |> Map.get(
      "boruta.patatoid.fr/backend-protocol",
      Map.get(annotations, "nginx.ingress.kubernetes.io/backend-protocol", "HTTP")
    )
    |> String.downcase()
    |> case do
      "https" -> "https"
      _ -> "http"
    end
  end

  defp truthy_annotation?(annotations, key) do
    annotations
    |> Map.get(key, "false")
    |> String.downcase()
    |> truthy?()
  end

  defp truthy?(value), do: value in ["true", "1", "yes"]

  defp integer_annotation(annotations, key) do
    annotations
    |> Map.get(key, "")
    |> String.to_integer()
  end

  defp string_annotation(annotations, key) do
    annotations
    |> Map.get(key, "")
  end

  defp put_boolean_annotation(upstream, annotations, field, key) do
    put_annotation(upstream, annotations, field, key, &truthy?/1)
  end

  defp put_string_annotation(upstream, annotations, field, key) do
    put_annotation(upstream, annotations, field, key, & &1)
  end

  defp put_map_annotation(upstream, annotations, field, key) do
    put_annotation(upstream, annotations, field, key, fn value -> Jason.decode!(value) end)
  end

  defp put_annotation(upstream, annotations, field, key, transform) do
    case Map.fetch(annotations, key) do
      {:ok, value} -> Map.put(upstream, field, transform.(value))
      :error -> upstream
    end
  end

  defp managed_id(namespace, ingress_name, virtual_host, uri, service_name, service_port) do
    port =
      cond do
        Map.has_key?(service_port, "number") -> Map.get(service_port, "number")
        Map.has_key?(service_port, "name") -> Map.get(service_port, "name")
        true -> "unknown"
      end

    [
      namespace,
      ingress_name,
      virtual_host || "*",
      uri,
      service_name,
      port
    ]
    |> Enum.map_join("|", &to_string/1)
  end

  defp service_host(service_name, namespace) do
    "#{service_name}.#{namespace}.svc.cluster.local"
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path("/" <> _path = path), do: path
  defp normalize_path(path), do: "/" <> path

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
