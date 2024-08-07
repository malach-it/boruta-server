defmodule BorutaAdmin.Release do
  @moduledoc false

  def load_configuration do
    Application.ensure_all_started(:boruta_admin)

    configuration_path = Application.get_env(:boruta_admin, :configuration_path)

    BorutaAdmin.ConfigurationLoader.from_file!(configuration_path)
  end
end
