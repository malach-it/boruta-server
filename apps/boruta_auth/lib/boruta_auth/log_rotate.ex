defmodule BorutaAuth.LogRotate do
  @moduledoc false

  def rotate do
    # TODO setup a configuration that help deleting older files

    Logger.configure_backend({LoggerFileBackend, :file_logger}, [path: path(Date.utc_today())])
  end

  @spec path(date :: Date.t()) :: path :: String.t()
  def path(date) do
    "./log/#{Date.to_string(date)}_boruta.log"
  end
end
