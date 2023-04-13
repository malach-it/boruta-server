defmodule BorutaGateway.ConfigurationLoader do
  alias BorutaGateway.Upstreams

  @spec from_file!(configuration_file_path :: String.t()) :: :ok
  def from_file!(path) do
    %{
      "configuration" => %{
        "gateway" => gateway_configuration
      }
    } = YamlElixir.read_from_file!(path)

    {:ok, _upstream} = Upstreams.create_upstream(gateway_configuration)

    :ok
  end
end
