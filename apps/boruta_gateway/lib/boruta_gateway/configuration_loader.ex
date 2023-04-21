defmodule BorutaGateway.ConfigurationLoader do
  @moduledoc false

  alias BorutaGateway.ConfigurationSchemas.GatewaySchema
  alias BorutaGateway.Upstreams

  @spec from_file!(configuration_file_path :: String.t()) :: :ok
  def from_file!(path) do
    %{
      "configuration" => %{
        "gateway" => gateway_configuration
      }
    } = YamlElixir.read_from_file!(path)

    case ExJsonSchema.Validator.validate(GatewaySchema.gateway(), gateway_configuration) do
      :ok ->
        {:ok, _upstream} = Upstreams.create_upstream(gateway_configuration)

        :ok

      {:error, errors} ->
        raise inspect(errors)
    end
  end
end
