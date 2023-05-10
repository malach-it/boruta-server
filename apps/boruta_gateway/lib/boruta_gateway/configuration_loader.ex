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

  @spec from_file!(configuration_file_path :: String.t()) :: :ok
  def from_file!(path) do
    %{"configuration" => configuration} = YamlElixir.read_from_file!(path)

    load_configuration!(configuration)
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
