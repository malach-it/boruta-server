defmodule BorutaGateway.ConfigurationLoader do
  @moduledoc false

  alias BorutaGateway.ConfigurationSchemas.GatewaySchema
  alias BorutaGateway.Upstreams

  @spec node_name() :: node_name :: String.t()
  def node_name do
    case Application.get_env(__MODULE__, :node_name) do
      nil ->
        path = Application.get_env(:boruta_gateway, :configuration_path)

        %{
          "configuration" => %{
            "node_name" => node_name
          }
        } = YamlElixir.read_from_file!(path)

        Application.put_env(__MODULE__, :node_name, node_name)
        node_name

      node_name ->
        node_name
    end
  rescue
    _ ->
      node_name = Atom.to_string(node())
      Application.put_env(__MODULE__, :node_name, node_name)
      node_name
  end

  @spec aliases() :: aliases :: list(String.t())
  def aliases do
    case Application.get_env(__MODULE__, :aliases) do
      nil ->
        path = Application.get_env(:boruta_gateway, :configuration_path)

        %{
          "configuration" => configuration
        } = YamlElixir.read_from_file!(path)

        aliases = Map.get(configuration, "aliases", []) |> with_default_aliases()
        Application.put_env(__MODULE__, :aliases, aliases)
        aliases

      aliases ->
        with_default_aliases(aliases)
    end
  rescue
    _ ->
      aliases = with_default_aliases([])
      Application.put_env(__MODULE__, :aliases, aliases)
      aliases
  end

  @spec from_file!(configuration_file_path :: String.t()) :: :ok
  def from_file!(path) do
    %{"configuration" => configuration} = YamlElixir.read_from_file!(path)

    case Map.fetch(configuration, "node_name") do
      {:ok, node_name} -> Application.put_env(__MODULE__, :node_name, node_name)
      :error -> :ok
    end

    case Map.fetch(configuration, "aliases") do
      {:ok, aliases} -> Application.put_env(__MODULE__, :aliases, with_default_aliases(aliases))
      :error -> Application.put_env(__MODULE__, :aliases, with_default_aliases([]))
    end

    load_configuration!(configuration)
  end

  defp with_default_aliases(aliases) do
    aliases
    |> Kernel.++([node_hostname()])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp node_hostname do
    node()
    |> Atom.to_string()
    |> String.split("@", parts: 2)
    |> case do
      [_name, host] ->
        host

      [_name] ->
        case :inet.gethostname() do
          {:ok, hostname} -> to_string(hostname)
          {:error, _reason} -> nil
        end
    end
  end

  defp load_configuration!(%{"gateway" => gateway_configurations} = configuration) do
    _created_upstreams =
      Enum.map(gateway_configurations, fn gateway_configuration ->
        case ExJsonSchema.Validator.validate(GatewaySchema.gateway(), gateway_configuration) do
          :ok ->
            {:ok, _upstream} = Upstreams.create_upstream(gateway_configuration)

            :ok

          {:error, errors} ->
            raise inspect(errors)
        end
      end)

    load_configuration!(Map.delete(configuration, "gateway"))
  end

  defp load_configuration!(%{"microgateway" => microgateway_configurations} = configuration) do
    _created_upstreams =
      Enum.map(microgateway_configurations, fn microgateway_configuration ->
        microgateway_configuration =
          Map.put(
            microgateway_configuration,
            "node_name",
            node_name()
          )

        case ExJsonSchema.Validator.validate(
               GatewaySchema.microgateway(),
               microgateway_configuration
             ) do
          :ok ->
            {:ok, _upstream} = Upstreams.create_upstream(microgateway_configuration)

            :ok

          {:error, errors} ->
            raise inspect(errors)
        end
      end)

    load_configuration!(Map.delete(configuration, "microgateway"))
  end

  defp load_configuration!(%{}), do: :ok
end
