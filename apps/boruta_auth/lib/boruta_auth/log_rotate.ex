defmodule BorutaAuth.LogRotate do
  @moduledoc false

  def rotate do
    today = Date.utc_today()
    max_retention_days = Application.get_env(:boruta_auth, BorutaAuth.LogRotate)[:max_retention_days]
    log_dates = log_dates(
      %{today|month: 1, day: 1},
      Date.add(today, -1 * max_retention_days)
    )

    Enum.map([:request, :business], fn type ->
      Enum.map([:boruta_web, :boruta_identity, :boruta_admin, :boruta_gateway], fn application ->
        _files_deleted? = Enum.map(log_dates, &path(application, type, &1))
        |> Enum.filter(&File.exists?/1)
        |> Enum.map(&File.rm/1)

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

  defp log_dates(start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      []
    else
      [start_date | log_dates(Date.add(start_date, 1), end_date)]
    end
  end
end
