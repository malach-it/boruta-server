defmodule BorutaAdmin.Logs.Adapters.File do
  @moduledoc false

  @behaviour BorutaAdmin.Logs.Adapter

  alias BorutaAdmin.Logs.FileTooLargeError
  alias BorutaAuth.LogRotate

  @default_max_file_size 100_000_000

  @impl true
  def earliest_at(application, type, _options) do
    earliest_date =
      "./log/*_#{application}_#{type}.log"
      |> Path.wildcard()
      |> Enum.flat_map(fn path ->
        path
        |> Path.basename()
        |> String.slice(0, 10)
        |> Date.from_iso8601()
        |> case do
          {:ok, date} -> [date]
          _ -> []
        end
      end)
      |> Enum.min_by(&Date.to_gregorian_days/1, fn -> Date.utc_today() end)

    DateTime.new!(earliest_date, ~T[00:00:00], "Etc/UTC")
  end

  @impl true
  def stream(start_at, end_at, application, type, query, options) do
    paths =
      log_dates(DateTime.to_date(start_at), DateTime.to_date(end_at))
      |> Enum.map(&LogRotate.path(application, type, &1))
      |> Enum.filter(&File.exists?/1)

    max_file_size = Keyword.get(options, :max_file_size, @default_max_file_size)

    if total_file_size(paths) > max_file_size do
      raise FileTooLargeError,
            "Requested for more than #{max_file_size} bytes of logs, could not perform the request."
    end

    paths
    |> Enum.map(&File.stream!/1)
    |> Stream.concat()
    |> Stream.drop_while(&log_before?(&1, start_at, true))
    |> Stream.take_while(&log_before?(&1, end_at, true))
    |> filter_by_text(query)
  end

  defp filter_by_text(stream, %{text: text}) when is_binary(text) and text != "" do
    Stream.filter(stream, &String.contains?(&1, text))
  end

  defp filter_by_text(stream, _query), do: stream

  defp log_before?(log, boundary, invalid_result) do
    case DateTime.from_iso8601(log |> String.split(" ") |> List.first()) do
      {:ok, log_time, _offset} -> DateTime.compare(log_time, boundary) == :lt
      _ -> invalid_result
    end
  end

  defp total_file_size(paths) do
    Enum.reduce(paths, 0, fn path, acc -> acc + File.stat!(path).size end)
  end

  defp log_dates(start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      []
    else
      [start_date | log_dates(Date.add(start_date, 1), end_date)]
    end
  end
end
