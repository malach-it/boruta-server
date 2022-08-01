defmodule BorutaAdmin.Logs do
  @moduledoc false

  alias BorutaAuth.LogRotate

  @spec read(start_at :: DateTime.t(), end_at :: DateTime.t()) :: Enumerable.t()
  def read(start_at, end_at) do
    log_dates(DateTime.to_date(start_at), DateTime.to_date(end_at))
    |> Enum.map(&LogRotate.path/1)
    |> Enum.filter(fn path -> File.exists?(path) end)
    |> Enum.map(&File.stream!/1)
    |> Stream.concat()
    |> Stream.drop_while(fn log ->
      case DateTime.from_iso8601(String.split(log, " ") |> List.first()) do
        {:ok, log_time, _offset} ->
          DateTime.compare(log_time, start_at) == :lt
        _ -> true
      end
    end)
    |> Stream.take_while(fn log ->
      case DateTime.from_iso8601(String.split(log, " ") |> List.first()) do
        {:ok, log_time, _offset} ->
          DateTime.compare(log_time, end_at) == :lt
        _ ->
          true
      end
    end)
  end

  defp log_dates(start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      []
    else
      [start_date|log_dates(Date.add(start_date, 1), end_date)]
    end
  end
end
