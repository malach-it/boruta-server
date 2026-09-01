defmodule BorutaAdminWeb.Logger do
  @moduledoc false

  require Logger
  alias Plug.Conn
  @behaviour Plug

  @identifier_parameter_names ~w(id backend_id identity_provider_id template_type)
  @parameter_allowlist %{
    "backend" => [
      {[:create], ~w(backend id), "backend_id"},
      {[:create, :update], ~w(backend name), "name"},
      {[:create, :update], ~w(backend type), "type"},
      {[:create, :update], ~w(backend is_default), "is_default"},
      {[:create, :update], ~w(backend create_default_organization),
       "create_default_organization"},
      {[:create, :update], ~w(backend smtp_ssl), "smtp_ssl"},
      {[:create, :update], ~w(backend smtp_tls), "smtp_tls"},
      {[:create, :update], ~w(backend smtp_port), "smtp_port"},
      {[:create, :update], ~w(backend ldap_pool_size), "ldap_pool_size"},
      {[:create, :update], ~w(backend password_hashing_alg), "password_hashing_alg"}
    ],
    "client" => [
      {[:create], ~w(client id), "client_id"},
      {[:create, :update], ~w(client name), "name"},
      {[:create, :update], ~w(client public_client_id), "public_client_id"},
      {[:create, :update], ~w(client confidential), "confidential"},
      {[:create, :update], ~w(client check_public_client_id), "check_public_client_id"},
      {[:create, :update], ~w(client pkce), "pkce"},
      {[:create, :update], ~w(client authorize_scope), "authorize_scope"},
      {[:create, :update], ~w(client enforce_dpop), "enforce_dpop"},
      {[:create, :update], ~w(client enforce_tx_code), "enforce_tx_code"},
      {[:create, :update], ~w(client public_refresh_token), "public_refresh_token"},
      {[:create, :update], ~w(client public_revoke), "public_revoke"},
      {[:create, :update], ~w(client access_token_ttl), "access_token_ttl"},
      {[:create, :update], ~w(client agent_token_ttl), "agent_token_ttl"},
      {[:create, :update], ~w(client authorization_code_ttl), "authorization_code_ttl"},
      {[:create, :update], ~w(client authorization_request_ttl), "authorization_request_ttl"},
      {[:create, :update], ~w(client id_token_ttl), "id_token_ttl"},
      {[:create, :update], ~w(client refresh_token_ttl), "refresh_token_ttl"},
      {[:create, :update], ~w(client supported_grant_types), "supported_grant_types"},
      {[:create, :update], ~w(client token_endpoint_auth_methods), "token_endpoint_auth_methods"},
      {[:create, :update], ~w(client token_endpoint_jwt_auth_alg), "token_endpoint_jwt_auth_alg"},
      {[:create, :update], ~w(client id_token_signature_alg), "id_token_signature_alg"},
      {[:create, :update], ~w(client id_token_kid), "id_token_kid"},
      {[:create, :update], ~w(client userinfo_signed_response_alg),
       "userinfo_signed_response_alg"},
      {[:create, :update], ~w(client signatures_adapter), "signatures_adapter"},
      {[:create, :update], ~w(client response_mode), "response_mode"},
      {[:create, :update], ~w(client key_pair_type type), "key_pair_type"},
      {[:create, :update], ~w(client key_pair_type curve), "key_pair_curve"},
      {[:create, :update], ~w(client key_pair_type modulus_size), "key_pair_modulus_size"},
      {[:create, :update], ~w(client identity_provider id), "identity_provider_id"},
      {[:create, :update], ~w(client key_pair_id), "key_pair_id"}
    ],
    "identity_provider" => [
      {[:create], ~w(identity_provider id), "identity_provider_id"},
      {[:create, :update], ~w(identity_provider backend_id), "backend_id"},
      {[:create, :update], ~w(identity_provider check_password), "check_password"},
      {[:create, :update], ~w(identity_provider choose_session), "choose_session"},
      {[:create, :update], ~w(identity_provider totpable), "totpable"},
      {[:create, :update], ~w(identity_provider enforce_totp), "enforce_totp"},
      {[:create, :update], ~w(identity_provider webauthnable), "webauthnable"},
      {[:create, :update], ~w(identity_provider enforce_webauthn), "enforce_webauthn"},
      {[:create, :update], ~w(identity_provider registrable), "registrable"},
      {[:create, :update], ~w(identity_provider user_editable), "user_editable"},
      {[:create, :update], ~w(identity_provider consentable), "consentable"},
      {[:create, :update], ~w(identity_provider confirmable), "confirmable"}
    ],
    "key_pair" => [
      {[:create, :update], ~w(key_pair is_default), "is_default"}
    ],
    "logs" => [
      {[:index], ["application"], "application"},
      {[:index], ["type"], "log_type"},
      {[:index], ["events_only"], "events_only"}
    ],
    "scope" => [
      {[:create], ~w(scope id), "scope_id"},
      {[:create, :update], ~w(scope name), "name"},
      {[:create, :update], ~w(scope label), "label"},
      {[:create, :update], ~w(scope public), "public"}
    ],
    "upstream" => [
      {[:create, :update], ~w(upstream scheme), "scheme"},
      {[:create, :update], ~w(upstream port), "port"},
      {[:create, :update], ~w(upstream strip_uri), "strip_uri"},
      {[:create, :update], ~w(upstream authorize), "authorize"},
      {[:create, :update], ~w(upstream authorization_type), "authorization_type"},
      {[:create, :update], ~w(upstream error_content_type), "error_content_type"},
      {[:create, :update], ~w(upstream forwarded_token_signature_alg),
       "forwarded_token_signature_alg"},
      {[:create, :update], ~w(upstream mtls_enabled), "mtls_enabled"},
      {[:create, :update], ~w(upstream rate_limit_enabled), "rate_limit_enabled"},
      {[:create, :update], ~w(upstream rate_limit_count), "rate_limit_count"},
      {[:create, :update], ~w(upstream rate_limit_time_unit), "rate_limit_time_unit"},
      {[:create, :update], ~w(upstream rate_limit_penality), "rate_limit_penality"},
      {[:create, :update], ~w(upstream rate_limit_timeout), "rate_limit_timeout"},
      {[:create, :update], ~w(upstream rate_limit_memory_length), "rate_limit_memory_length"}
    ],
    "user" => [
      {[:create], ["backend_id"], "backend_id"}
    ]
  }

  @impl true
  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  @impl true
  def call(conn, level) do
    start = System.monotonic_time()

    Conn.register_before_send(
      conn,
      fn conn ->
        log_request(conn, level, start)
        log_business_event(conn)

        conn
      end
    )
  end

  @spec start() :: [:ok | {:error, term()}]
  def start do
    :logger.add_handler_filter(
      :default,
      :boruta_admin_remote_cli,
      {&__MODULE__.remote_cli_console_filter/2, :ok}
    )

    handlers = [
      {:boruta_admin_console_authentication_success, :success},
      {:boruta_admin_console_authentication_failure, :failure}
    ]

    for {handler_id, result} <- handlers do
      :telemetry.attach(
        handler_id,
        [:boruta_admin, :console, :authentication, result],
        &__MODULE__.console_authentication_handler/4,
        :ok
      )
    end
  end

  def remote_cli_console_filter(%{meta: %{boruta_cli_remote: true}}, _config), do: :stop
  def remote_cli_console_filter(_event, _config), do: :ignore

  @spec console_authentication_handler(
          [atom()],
          map(),
          %{
            required(:client_id) => String.t(),
            required(:sub) => String.t(),
            required(:request_id) => String.t()
          },
          term()
        ) :: :ok
  def console_authentication_handler(
        [:boruta_admin, :console, :authentication, result],
        _measurements,
        %{client_id: client_id, sub: sub, request_id: request_id},
        _config
      )
      when result in [:success, :failure] do
    Logger.log(
      :info,
      fn ->
        [
          "boruta_admin console authenticate - ",
          Atom.to_string(result),
          log_attribute("client_id", client_id),
          log_attribute("sub", sub)
        ]
      end,
      application: :boruta_admin,
      type: :business,
      request_id: request_id
    )
  end

  defp log_request(conn, level, start) do
    Logger.log(
      level,
      fn ->
        remote_ip = :inet.ntoa(conn.remote_ip)
        stop = System.monotonic_time()
        duration = System.convert_time_unit(stop - start, :native, :microsecond)
        status = Integer.to_string(conn.status)

        [
          "boruta_admin",
          ?\s,
          conn.method,
          ?\s,
          conn.request_path,
          " - ",
          connection_type(conn.state),
          ?\s,
          status,
          " from ",
          remote_ip,
          " in ",
          duration(duration)
        ]
      end,
      type: :request
    )
  end

  defp log_business_event(%{
         assigns: assigns,
         path_info: ["api" | _],
         path_params: path_params,
         params: params,
         private: %{phoenix_action: action, phoenix_controller: controller},
         resp_body: resp_body,
         status: status
       }) do
    resource =
      controller
      |> Module.split()
      |> List.last()
      |> String.trim_trailing("Controller")
      |> Macro.underscore()

    result = if status < 400, do: "success", else: "failure"

    Logger.log(
      :info,
      fn ->
        [
          "boruta_admin",
          ?\s,
          resource,
          ?\s,
          Atom.to_string(action),
          " - ",
          result,
          principal_attributes(assigns),
          identifier_attributes(resource, path_params),
          parameter_attributes(resource, action, params),
          failure_attributes(status, resp_body)
        ]
      end,
      application: :boruta_admin,
      type: :business
    )
  end

  defp log_business_event(_conn), do: :ok

  defp principal_attributes(%{authorization: %{"sub" => sub}}) when is_binary(sub) do
    log_attribute("sub", sub)
  end

  defp principal_attributes(_assigns), do: []

  defp identifier_attributes(resource, path_params) do
    path_params
    |> Map.take(@identifier_parameter_names)
    |> Enum.sort()
    |> Enum.map(fn
      {"id", identifier} -> log_attribute("#{resource}_id", identifier)
      {name, identifier} -> log_attribute(name, identifier)
    end)
  end

  defp parameter_attributes(resource, action, params) when is_map(params) do
    @parameter_allowlist
    |> Map.get(resource, [])
    |> Enum.flat_map(fn {actions, path, attribute_name} ->
      if action in actions do
        case get_in(params, path) do
          value
          when (is_binary(value) and value != "") or is_boolean(value) or is_number(value) ->
            [log_attribute(attribute_name, value)]

          value when is_list(value) ->
            log_list_attribute(attribute_name, value)

          _ ->
            []
        end
      else
        []
      end
    end)
  end

  defp parameter_attributes(_resource, _action, _params), do: []

  defp failure_attributes(status, response_body) when status >= 400 do
    with {:ok, response_body} <- response_body |> IO.iodata_to_binary() |> Jason.decode(),
         true <- is_map(response_body) do
      ~w(code message)
      |> Enum.flat_map(fn attribute_name ->
        case Map.get(response_body, attribute_name) do
          value when is_binary(value) and value != "" ->
            [log_attribute(attribute_name, value)]

          _ ->
            []
        end
      end)
    else
      _ -> []
    end
  rescue
    ArgumentError -> []
  end

  defp failure_attributes(_status, _response_body), do: []

  defp log_list_attribute(name, values) do
    if values != [] and Enum.all?(values, &(is_binary(&1) and &1 != "")) do
      [log_attribute(name, values |> Enum.take(20) |> Enum.join(","))]
    else
      []
    end
  end

  defp log_attribute(name, value) do
    encoded_value =
      value
      |> to_string()
      |> String.slice(0, 256)
      |> URI.encode_www_form()

    [" ", name, "=", encoded_value]
  end

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end

  defp connection_type(%{state: :set_chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"
end
