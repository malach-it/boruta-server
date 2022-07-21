defmodule BorutaAuth.LogRotate do
  @moduledoc false

  def rotate do
    # TODO setup a configuration that help deleting older files
    path = "./log/#{Date.utc_today() |> Date.to_string()}_boruta.log"

    Logger.configure_backend({LoggerFileBackend, :file_logger}, [path: path])
  end
end
