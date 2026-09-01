defmodule BorutaAdmin.ReleaseCommand do
  @moduledoc false

  alias BorutaAdmin.Cli
  alias BorutaAdmin.Yaml

  @spec main([String.t()]) :: :ok
  def main([resource, action | arguments]) do
    {request_params, plain_arguments} = parse_arguments(arguments)
    possible_resource_id = List.first(plain_arguments)

    result =
      quietly(fn ->
        with :ok <- start_dependencies() do
          Cli.call(resource, action, possible_resource_id, request_params)
        end
      end)

    with {:ok, %Plug.Conn{} = response} <- result do
      attributes = attributes(response, plain_arguments)

      response
      |> response_body()
      |> filter_response(attributes)
      |> Yaml.encode()
      |> IO.write()

      if response.status >= 400, do: System.halt(1)
    else
      {:error, reason} ->
        IO.puts(:stderr, "boruta-cli failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def main(_args) do
    IO.puts(
      :stderr,
      "Usage: boruta-cli <resource> <action> [resource-id] [key:value ...] [attribute ...]"
    )

    System.halt(64)
  end

  defp quietly(fun) do
    original_group_leader = Process.group_leader()
    {:ok, group_leader_sink} = StringIO.open("")

    muted_logger_handlers =
      [:default, :ssl_handler]
      |> Enum.map(&mute_logger_handler/1)
      |> Enum.reject(&is_nil/1)

    muted_devices = [:standard_error] |> Enum.map(&mute_device/1) |> Enum.reject(&is_nil/1)

    Process.group_leader(self(), group_leader_sink)

    try do
      fun.()
    after
      Logger.flush()
      Process.group_leader(self(), original_group_leader)
      Enum.each(Enum.reverse(muted_devices), &restore_device/1)
      Enum.each(Enum.reverse(muted_logger_handlers), &restore_logger_handler/1)
      StringIO.close(group_leader_sink)
    end
  end

  defp mute_logger_handler(handler_id) do
    case :logger.get_handler_config(handler_id) do
      {:ok, %{module: module} = config} ->
        :ok = :logger.remove_handler(handler_id)
        {handler_id, module, Map.drop(config, [:id, :module])}

      {:error, _reason} ->
        nil
    end
  end

  defp restore_logger_handler({handler_id, module, config}) do
    :ok = :logger.add_handler(handler_id, module, config)
  end

  defp mute_device(name) do
    case Process.whereis(name) do
      nil ->
        nil

      original_device ->
        {:ok, sink} = StringIO.open("")

        Process.unregister(name)
        Process.register(sink, name)

        {name, original_device, sink}
    end
  end

  defp restore_device({name, original_device, sink}) do
    Process.unregister(name)
    Process.register(original_device, name)
    StringIO.close(sink)
  end

  defp start_dependencies do
    disable_network_listeners()

    case Application.ensure_all_started(:boruta_admin) do
      {:ok, _applications} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp disable_network_listeners do
    [
      {:boruta_admin, BorutaAdminWeb.Endpoint},
      {:boruta_identity, BorutaIdentityWeb.Endpoint},
      {:boruta_web, BorutaWeb.Endpoint}
    ]
    |> Enum.each(fn {application, endpoint} ->
      config = Application.get_env(application, endpoint, [])
      Application.put_env(application, endpoint, Keyword.put(config, :server, false))
    end)

    [
      :server,
      :sidecar_server,
      :proxy_server,
      :https_proxy_server,
      :https_server,
      :sidecar_https_server
    ]
    |> Enum.each(&Application.put_env(:boruta_gateway, &1, false))

    # The CLI manages the database-backed configuration directly. Loading the
    # gateway's static configuration here is unrelated to the command and can
    # overwrite those database values (or prevent the CLI from starting when a
    # relative configuration path is not valid from the caller's directory).
    Application.put_env(:boruta_gateway, :configuration_path, nil)
  end

  defp response_body(%Plug.Conn{resp_body: body}) when body in [nil, ""], do: nil

  defp response_body(%Plug.Conn{resp_body: body}) do
    body = IO.iodata_to_binary(body)

    case Jason.decode(body) do
      {:ok, value} -> value
      {:error, _error} -> body
    end
  end

  defp attributes(_response, []), do: []

  defp attributes(response, [possible_resource_id | attributes] = arguments) do
    if resource_id?(response.path_params, possible_resource_id), do: attributes, else: arguments
  end

  defp parse_arguments(arguments) do
    Enum.reduce(arguments, {%{}, []}, fn argument, {request_params, attributes} ->
      case String.split(argument, ":", parts: 2) do
        [key, value] when key != "" ->
          {Map.put(request_params, key, unquote_parameter(value)), attributes}

        _attribute ->
          {request_params, attributes ++ [argument]}
      end
    end)
  end

  defp unquote_parameter(<<quote, rest::binary>> = value) when quote in [?", ?'] do
    if String.ends_with?(rest, <<quote>>) do
      binary_part(rest, 0, byte_size(rest) - 1)
    else
      value
    end
  end

  defp unquote_parameter(value), do: value

  defp filter_response(body, []), do: body

  defp filter_response(body, attributes) do
    case select_attributes(body, MapSet.new(attributes)) do
      :not_found -> %{}
      filtered -> filtered
    end
  end

  defp resource_id?(path_params, possible_resource_id) do
    Enum.any?(path_params, fn {name, value} ->
      (name == "id" || String.ends_with?(name, "_id")) && value == possible_resource_id
    end)
  end

  defp select_attributes(value, attributes) when is_map(value) do
    selected = Map.take(value, MapSet.to_list(attributes))

    if map_size(selected) > 0 do
      selected
    else
      value
      |> Enum.reduce(%{}, fn {key, child}, selected_children ->
        case select_attributes(child, attributes) do
          :not_found -> selected_children
          result -> Map.put(selected_children, key, result)
        end
      end)
      |> case do
        empty when map_size(empty) == 0 -> :not_found
        selected_children -> selected_children
      end
    end
  end

  defp select_attributes(value, attributes) when is_list(value) do
    value
    |> Enum.map(&select_attributes(&1, attributes))
    |> Enum.reject(&(&1 == :not_found))
    |> case do
      [] -> :not_found
      selected -> selected
    end
  end

  defp select_attributes(_value, _attributes), do: :not_found
end
