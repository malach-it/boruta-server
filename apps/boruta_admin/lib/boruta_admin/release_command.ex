defmodule BorutaAdmin.ReleaseCommand do
  @moduledoc false

  alias BorutaAdmin.Cli
  alias BorutaAdmin.Yaml

  @colon_uri_schemes ~w(data did mailto tel urn)
  @remote_error_marker "\n__BORUTA_CLI_ERROR__"
  @usage "Usage: boruta-cli <resource> <action> [resource-id] [attribute-or-selector ...] [-- key[:nested-key...]:value ...]"

  @spec main([String.t()]) :: :ok
  def main([resource, action | arguments]) do
    outcome =
      safely(fn ->
        {request_params, plain_arguments} = parse_arguments(arguments)
        possible_resource_id = List.first(plain_arguments)

        result =
          quietly(fn ->
            with :ok <- start_dependencies() do
              Cli.call(resource, action, possible_resource_id, request_params)
            end
          end)

        write_result(result, plain_arguments)
      end)

    case outcome do
      :ok -> :ok
      {:error, :response} -> System.halt(1)
      {:error, reason} -> write_error(reason, 1)
    end
  end

  def main(_args) do
    write_error(@usage, 64)
  end

  @spec remote([String.t()]) :: :ok
  def remote([resource, action | arguments]) do
    previous_logger_metadata = Logger.metadata()
    Logger.metadata(boruta_cli_remote: true)

    try do
      outcome =
        safely(fn ->
          {request_params, plain_arguments} = parse_arguments(arguments)
          possible_resource_id = List.first(plain_arguments)
          result = Cli.call(resource, action, possible_resource_id, request_params)

          write_result(result, plain_arguments)
        end)

      case outcome do
        :ok -> :ok
        {:error, :response} -> IO.write(@remote_error_marker)
        {:error, reason} -> write_remote_error(reason)
      end
    after
      Logger.reset_metadata(previous_logger_metadata)
    end
  end

  def remote(_args) do
    write_remote_error(@usage)
  end

  defp write_result({:ok, %Plug.Conn{} = response}, plain_arguments) do
    attributes = attributes(response, plain_arguments)

    response
    |> response_body()
    |> filter_response(attributes)
    |> Yaml.encode()
    |> IO.write()

    if response.status >= 400, do: {:error, :response}, else: :ok
  end

  defp write_result({:error, reason}, _plain_arguments), do: {:error, reason}

  defp write_error(reason, exit_status) do
    reason |> error_document() |> Yaml.encode() |> IO.write()
    System.halt(exit_status)
  end

  defp write_remote_error(reason) do
    reason |> error_document() |> Yaml.encode() |> IO.write()
    IO.write(@remote_error_marker)
  end

  defp error_document(reason) do
    message = error_message(reason)

    %{
      "code" => "CLI_ERROR",
      "message" => message,
      "errors" => %{"resource" => [message]}
    }
  end

  defp error_message(%_{} = exception) do
    Exception.message(exception)
  rescue
    _error -> inspect(exception)
  end

  defp error_message(
         {:client_authentication, %Boruta.Oauth.Error{error_description: error_description}}
       ),
       do: error_description

  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(reason), do: inspect(reason)

  defp safely(fun) do
    fun.()
  rescue
    exception -> {:error, exception}
  catch
    kind, reason -> {:error, {kind, reason}}
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

  @doc false
  @spec parse_arguments([String.t()]) :: {map(), [String.t()]}
  def parse_arguments(arguments) do
    case Enum.split_while(arguments, &(&1 != "--")) do
      {legacy_arguments, []} ->
        parse_request_arguments(legacy_arguments)

      {attributes, ["--" | filter_arguments]} ->
        {request_params, trailing_attributes} = parse_request_arguments(filter_arguments)
        {request_params, attributes ++ trailing_attributes}
    end
  end

  defp parse_request_arguments(arguments) do
    Enum.reduce(arguments, {%{}, []}, fn argument, {request_params, attributes} ->
      case String.split(argument, ":", parts: 2) do
        [key, value] when key != "" ->
          {nested_keys, value} = nested_parameter(value)

          request_params =
            put_nested_parameter(request_params, [key | nested_keys], unquote_parameter(value))

          {request_params, attributes}

        _attribute ->
          {request_params, attributes ++ [argument]}
      end
    end)
  end

  defp nested_parameter(value), do: nested_parameter_path(value)

  defp nested_parameter_path(value) do
    segments = split_unquoted_colons(value)

    quoted_value_index =
      if quoted_parameter?(List.last(segments)), do: length(segments) - 1

    value_index =
      quoted_value_index ||
        segments
        |> Enum.with_index()
        |> Enum.find_value(fn {segment, index} ->
          if uri_value_start?(segments, segment, index) do
            index
          end
        end)

    value_index = value_index || length(segments) - 1
    nested_keys = Enum.take(segments, value_index)

    if Enum.all?(nested_keys, &nested_key?/1) do
      {Enum.map(nested_keys, &normalize_nested_key/1),
       segments |> Enum.drop(value_index) |> Enum.join(":")}
    else
      {[], value}
    end
  end

  defp nested_key?(key),
    do: Regex.match?(~r/^(?:[a-zA-Z_][a-zA-Z0-9_-]*|0|[1-9][0-9]*)$/, key)

  defp normalize_nested_key(key) do
    if Regex.match?(~r/^(?:0|[1-9][0-9]*)$/, key), do: String.to_integer(key), else: key
  end

  defp split_unquoted_colons(value) do
    case split_unquoted_colons(value, [], "", nil) do
      {segments, nil} -> segments
      {_segments, _unterminated_quote} -> String.split(value, ":")
    end
  end

  defp split_unquoted_colons(<<>>, segments, segment, quote) do
    {Enum.reverse([segment | segments]), quote}
  end

  defp split_unquoted_colons(<<quote, rest::binary>>, segments, "", nil)
       when quote in [?", ?'] do
    split_unquoted_colons(rest, segments, <<quote>>, quote)
  end

  defp split_unquoted_colons(<<quote, rest::binary>>, segments, segment, quote) do
    split_unquoted_colons(rest, segments, segment <> <<quote>>, nil)
  end

  defp split_unquoted_colons(<<?:, rest::binary>>, segments, segment, nil) do
    split_unquoted_colons(rest, [segment | segments], "", nil)
  end

  defp split_unquoted_colons(<<character::utf8, rest::binary>>, segments, segment, quote) do
    split_unquoted_colons(rest, segments, segment <> <<character::utf8>>, quote)
  end

  defp quoted_parameter?(<<quote, rest::binary>>) when quote in [?", ?'] do
    String.ends_with?(rest, <<quote>>)
  end

  defp quoted_parameter?(_parameter), do: false

  defp uri_scheme?(segment), do: Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9+.-]*$/, segment)

  defp uri_value_start?(segments, segment, index) do
    segment in @colon_uri_schemes ||
      (uri_scheme?(segment) && match?("//" <> _rest, Enum.at(segments, index + 1)))
  end

  defp put_nested_parameter(parameters, [key], value) when is_map(parameters) and is_binary(key),
    do: Map.put(parameters, key, value)

  defp put_nested_parameter(parameters, [index], value)
       when is_list(parameters) and is_integer(index),
       do: put_list_index(parameters, index, value)

  defp put_nested_parameter(parameters, [key | nested_keys], value) do
    next_key = List.first(nested_keys)
    existing = nested_value(parameters, key)

    nested =
      existing
      |> nested_container(next_key)
      |> put_nested_parameter(nested_keys, value)

    put_nested_value(parameters, key, nested)
  end

  defp nested_value(parameters, key) when is_map(parameters) and is_binary(key),
    do: Map.get(parameters, key)

  defp nested_value(parameters, index) when is_list(parameters) and is_integer(index),
    do: Enum.at(parameters, index)

  defp nested_container(value, next_key) when is_integer(next_key) and is_list(value), do: value
  defp nested_container(value, next_key) when is_binary(next_key) and is_map(value), do: value
  defp nested_container(_value, next_key) when is_integer(next_key), do: []
  defp nested_container(_value, next_key) when is_binary(next_key), do: %{}

  defp put_nested_value(parameters, key, value) when is_map(parameters) and is_binary(key),
    do: Map.put(parameters, key, value)

  defp put_nested_value(parameters, index, value)
       when is_list(parameters) and is_integer(index),
       do: put_list_index(parameters, index, value)

  defp put_list_index(list, index, value) do
    list
    |> Kernel.++(List.duplicate(nil, max(index - length(list) + 1, 0)))
    |> List.replace_at(index, value)
  end

  defp unquote_parameter(<<quote, rest::binary>> = value) when quote in [?", ?'] do
    if String.ends_with?(rest, <<quote>>) do
      binary_part(rest, 0, byte_size(rest) - 1)
    else
      value
    end
  end

  defp unquote_parameter(value), do: value

  @doc false
  @spec filter_response(term(), [String.t()]) :: term()
  def filter_response(body, []), do: body

  def filter_response(body, attributes) do
    {path_selectors, attributes} = Enum.split_with(attributes, &String.contains?(&1, ":"))

    selected_attributes =
      if attributes == [], do: :not_found, else: select_attributes(body, MapSet.new(attributes))

    selected =
      Enum.reduce(path_selectors, selected_attributes, fn selector, selected ->
        selector
        |> selector_path()
        |> then(&select_path_anywhere(body, &1))
        |> merge_selection(selected)
      end)

    case selected do
      :not_found -> %{}
      filtered -> compact_selection(filtered)
    end
  end

  defp selector_path(selector) do
    selector
    |> String.split(":")
    |> Enum.map(&normalize_nested_key/1)
  end

  defp select_path_anywhere(value, path) do
    case select_path(value, path) do
      :not_found -> select_path_in_children(value, path)
      selected -> selected
    end
  end

  defp select_path_in_children(value, path) when is_map(value) do
    value
    |> Enum.reduce(%{}, fn {key, child}, selected_children ->
      case select_path_anywhere(child, path) do
        :not_found -> selected_children
        selected -> Map.put(selected_children, key, selected)
      end
    end)
    |> case do
      empty when map_size(empty) == 0 -> :not_found
      selected_children -> selected_children
    end
  end

  defp select_path_in_children(value, path) when is_list(value) do
    value
    |> Enum.map(&select_path_anywhere(&1, path))
    |> Enum.reject(&(&1 == :not_found))
    |> case do
      [] -> :not_found
      selected -> selected
    end
  end

  defp select_path_in_children(_value, _path), do: :not_found

  defp select_path(value, []), do: value

  defp select_path(value, [key | path]) when is_map(value) and is_binary(key) do
    with {:ok, child} <- Map.fetch(value, key),
         selected when selected != :not_found <- select_path(child, path) do
      Map.put(%{}, key, selected)
    else
      _error -> :not_found
    end
  end

  defp select_path(value, [index | path]) when is_list(value) and is_integer(index) do
    with {:ok, child} <- Enum.fetch(value, index),
         selected when selected != :not_found <- select_path(child, path) do
      List.duplicate(nil, index) ++ [selected]
    else
      _error -> :not_found
    end
  end

  defp select_path(_value, _path), do: :not_found

  defp merge_selection(:not_found, selected), do: selected
  defp merge_selection(selection, :not_found), do: selection

  defp merge_selection(selection, selected) when is_map(selection) and is_map(selected) do
    Map.merge(selected, selection, fn _key, selected_value, selection_value ->
      merge_selection(selection_value, selected_value)
    end)
  end

  defp merge_selection(selection, selected) when is_list(selection) and is_list(selected) do
    case max(length(selection), length(selected)) do
      0 ->
        []

      length ->
        Enum.map(0..(length - 1), fn index ->
          merge_selection(Enum.at(selection, index), Enum.at(selected, index))
        end)
    end
  end

  defp merge_selection(nil, selected), do: selected
  defp merge_selection(selection, nil), do: selection
  defp merge_selection(selection, _selected), do: selection

  defp compact_selection(value) when is_map(value) do
    Map.new(value, fn {key, child} -> {key, compact_selection(child)} end)
  end

  defp compact_selection(value) when is_list(value) do
    value
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&compact_selection/1)
  end

  defp compact_selection(value), do: value

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
