defmodule BorutaAdmin.Cli do
  @moduledoc """
  Handles resource actions shared by administration controllers and the
  `boruta-cli` release executable.

  Controller calls reuse their authenticated connection:

      BorutaAdmin.Cli.call(conn)

  Release-command calls resolve the resource and action through the admin
  router, generate a one-use access token, and build an authenticated
  connection:

      BorutaAdmin.Cli.call("upstream", "create")
      BorutaAdmin.Cli.call("upstream", "show", "upstream-id")
  """

  alias Boruta.AccessTokensAdapter
  alias Boruta.ClientsAdapter
  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Token
  alias BorutaAdminWeb.Authorization
  alias BorutaAdminWeb.Endpoint
  alias BorutaAdminWeb.Logger, as: BusinessLogger
  alias BorutaAdminWeb.Router

  @admin_client_id System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID")
  @token_ttl 60

  @controller_scopes %{
    BorutaAdminWeb.BackendController => "identity-providers:manage:all",
    BorutaAdminWeb.ClientController => "clients:manage:all",
    BorutaAdminWeb.ConfigurationController => "configuration:manage:all",
    BorutaAdminWeb.IdentityProviderController => "identity-providers:manage:all",
    BorutaAdminWeb.KeyPairController => "clients:manage:all",
    BorutaAdminWeb.LogsController => "logs:read:all",
    BorutaAdminWeb.OrganizationController => "users:manage:all",
    BorutaAdminWeb.RoleController => "scopes:manage:all",
    BorutaAdminWeb.ScopeController => "scopes:manage:all",
    BorutaAdminWeb.ServiceRegistryController => "upstreams:manage:all",
    BorutaAdminWeb.UpstreamController => "upstreams:manage:all",
    BorutaAdminWeb.UserController => "users:manage:all"
  }

  @type error_reason ::
          :unauthorized
          | {:access_token, term()}
          | {:client_not_found, String.t()}
          | {:invalid_controller_response, term()}
          | {:unknown_resource_action, String.t(), String.t()}

  @spec call(Plug.Conn.t()) :: {:ok, Plug.Conn.t()} | {:error, error_reason()}
  def call(%Plug.Conn{} = conn) do
    controller = conn.private[:phoenix_controller]
    action = conn.private[:phoenix_action]

    with {:ok, required_scope} <- required_scope(controller),
         true <- authorized?(conn, required_scope) do
      case controller.call(conn, action) do
        %Plug.Conn{} = response -> {:ok, response}
        response -> {:error, {:invalid_controller_response, response}}
      end
    else
      _ -> {:error, :unauthorized}
    end
  end

  @spec call(String.t() | atom(), String.t() | atom()) ::
          {:ok, Plug.Conn.t()} | {:error, error_reason()}
  def call(resource, action) when is_binary(resource) or is_atom(resource) do
    call(resource, action, nil)
  end

  @spec call(String.t() | atom(), String.t() | atom(), String.t() | nil) ::
          {:ok, Plug.Conn.t()} | {:error, error_reason()}
  def call(resource, action, resource_id)
      when (is_binary(resource) or is_atom(resource)) and
             (is_binary(resource_id) or is_nil(resource_id)) do
    call(resource, action, resource_id, %{})
  end

  @spec call(String.t() | atom(), String.t() | atom(), String.t() | nil, map()) ::
          {:ok, Plug.Conn.t()} | {:error, error_reason()}
  def call(resource, action, resource_id, request_params)
      when (is_binary(resource) or is_atom(resource)) and
             (is_binary(resource_id) or is_nil(resource_id)) and is_map(request_params) do
    request_id = Plug.RequestId.generate()
    previous_logger_metadata = Logger.metadata()
    Logger.metadata(request_id: request_id)

    try do
      call(resource, action, resource_id, request_params, request_id)
    after
      Logger.reset_metadata(previous_logger_metadata)
    end
  end

  defp call(resource, action, resource_id, request_params, request_id) do
    resource = to_string(resource)
    action = to_string(action)

    with {:ok, route, required_scope} <- resolve_route(resource, action),
         %Client{} = client <- admin_client(),
         {:ok, %Token{} = token, sub} <-
           create_access_token(client, required_scope, request_id) do
      try do
        route
        |> authenticated_conn(token, required_scope, resource_id, request_params, sub)
        |> case do
          {:ok, conn} ->
            conn
            |> BusinessLogger.call(BusinessLogger.init([]))
            |> call()

          {:error, reason} ->
            {:error, reason}
        end
      after
        AccessTokensAdapter.revoke(token)
      end
    else
      nil -> {:error, {:client_not_found, admin_client_id()}}
      {:error, {:unknown_resource_action, _, _} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:access_token, reason}}
    end
  end

  defp resolve_route(resource, action) do
    normalized_resource = resource |> String.replace("-", "_") |> String.trim()
    normalized_action = String.trim(action)

    route =
      Router.__routes__()
      |> Enum.find(fn route ->
        String.starts_with?(route.path, "/api") and
          resource_name(route.plug) == normalized_resource and
          to_string(route.plug_opts) == normalized_action
      end)

    with %{plug: controller} = route <- route,
         {:ok, required_scope} <- required_scope(controller) do
      {:ok, route, required_scope}
    else
      _ -> {:error, {:unknown_resource_action, resource, action}}
    end
  end

  defp admin_client do
    admin_client_id()
    |> ClientsAdapter.get_client()
    |> case do
      %Client{} = client -> %{client | access_token_ttl: @token_ttl}
      nil -> nil
    end
  end

  defp admin_client_id do
    System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", @admin_client_id)
  end

  defp create_access_token(client, scope, request_id) do
    sub = console_subject()

    result =
      AccessTokensAdapter.create(
        %{
          client: client,
          scope: scope
        },
        []
      )

    authentication_result = if match?({:ok, %Token{}}, result), do: :success, else: :failure

    :telemetry.execute(
      [:boruta_admin, :console, :authentication, authentication_result],
      %{},
      %{client_id: client.id, sub: sub, request_id: request_id}
    )

    case result do
      {:ok, %Token{} = token} -> {:ok, token, sub}
      error -> error
    end
  end

  defp console_subject do
    System.get_env("BORUTA_COMMAND_SUB") || default_console_subject()
  end

  defp default_console_subject do
    username = System.get_env("USER") || System.get_env("USERNAME") || "unknown"

    hostname =
      case :inet.gethostname() do
        {:ok, hostname} -> List.to_string(hostname)
        {:error, _reason} -> "unknown"
      end

    "#{username}@#{hostname}"
  end

  defp authenticated_conn(route, token, required_scope, resource_id, request_params, sub) do
    path_params = path_params(route.path, resource_id)
    request_params = format_request_params(route, request_params)
    params = Map.merge(request_params, path_params)
    {query_params, body_params} = request_parameter_fields(route.verb, request_params)

    conn =
      route.verb
      |> Plug.Test.conn(materialize_path(route.path, path_params))
      |> Map.put(:params, params)
      |> Map.put(:path_params, path_params)
      |> Map.put(:query_params, query_params)
      |> Map.put(:body_params, body_params)
      |> Plug.Conn.put_private(:phoenix_controller, route.plug)
      |> Plug.Conn.put_private(:phoenix_action, route.plug_opts)
      |> Plug.Conn.put_private(:phoenix_router, Router)
      |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
      |> Plug.Conn.put_req_header("authorization", "Bearer #{token.value}")
      |> Authorization.require_authenticated([])
      |> assign_console_subject(sub)

    conn = if conn.halted, do: conn, else: Authorization.authorize(conn, [required_scope])

    if conn.halted, do: {:error, :unauthorized}, else: {:ok, conn}
  end

  defp assign_console_subject(%Plug.Conn{halted: true} = conn, _sub), do: conn

  defp assign_console_subject(conn, sub) do
    authorization = conn.assigns |> Map.fetch!(:authorization) |> Map.put("sub", sub)
    Plug.Conn.assign(conn, :authorization, authorization)
  end

  defp request_parameter_fields(verb, request_params)
       when verb in [:get, :delete, "GET", "DELETE"] do
    {request_params, %{}}
  end

  defp request_parameter_fields(_verb, request_params), do: {%{}, request_params}

  defp format_request_params(%{verb: verb}, request_params)
       when verb in [:get, :delete, "GET", "DELETE"] or map_size(request_params) == 0 do
    request_params
  end

  defp format_request_params(route, request_params) do
    %{resource_name(route.plug) => request_params}
  end

  defp authorized?(conn, required_scope) do
    conn.assigns
    |> get_in([:authorization, "scope"])
    |> to_string()
    |> String.split()
    |> Enum.member?(required_scope)
  end

  defp required_scope(controller) do
    case @controller_scopes do
      %{^controller => scope} -> {:ok, scope}
      _ -> {:error, :unknown_controller}
    end
  end

  defp materialize_path(path, path_params) do
    Regex.replace(~r/:([a-zA-Z_]+)/, path, fn _, name -> Map.fetch!(path_params, name) end)
  end

  defp path_params(path, resource_id) do
    ~r/:([a-zA-Z_]+)/
    |> Regex.scan(path, capture: :all_but_first)
    |> Map.new(fn [name] ->
      value =
        if resource_id && (name == "id" || String.ends_with?(name, "_id")) do
          resource_id
        else
          "boruta-cli"
        end

      {name, value}
    end)
  end

  defp resource_name(controller) when is_atom(controller) do
    controller
    |> Module.split()
    |> List.last()
    |> String.replace_suffix("Controller", "")
    |> Macro.underscore()
  end

  defp resource_name(controller), do: to_string(controller)
end
