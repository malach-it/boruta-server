defmodule BorutaAuth.LogRotate do
  @moduledoc false

  def rotate do
    # TODO setup a configuration that help deleting older files

    Enum.map([:request, :business], fn type ->
      Enum.map([:boruta_web, :boruta_identity, :boruta_admin, :boruta_gateway], fn application ->
        Logger.configure_backend({LoggerFileBackend, :"#{application}_#{type}_logger"},
          path: path(application, type, Date.utc_today())
        )
      end)
    end)
  end

  @spec path(application :: atom(), type :: atom(), date :: Date.t()) :: path :: String.t()
  def path(application, type, date) do
    "./log/#{Date.to_string(date)}_#{application}_#{type}.log"
  end
end
