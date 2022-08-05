defmodule BorutaAdmin.Logs do
  @moduledoc false

  alias BorutaAuth.LogRotate

  @max_log_lines 20_000
  @request_log_regex ~r/(\d{4}-\d{2}-\d{2}T[^\s]+Z) request_id=([^\s]+) \[info\] (\w+) (\w+) ([^\s]+) - (\w+) (\d{3}) in (\d+)(\w+)/

  @spec read(start_at :: DateTime.t(), end_at :: DateTime.t()) :: Enumerable.t()
  def read(start_at, end_at) do
    time_scale_unit = time_scale_unit(start_at, end_at)

    log_stream(start_at, end_at)
    |> Stream.map(&parse_request_log/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.reduce(
        %{
          time_scale_unit: time_scale_unit,
          overflow: false,
          log_lines: [],
          log_count: 0,
          status_codes: %{},
          request_counts: %{},
          request_times: %{},
        },
      fn %{
           label: label,
           log_line: log_line,
           time: time,
           status_code: status_code,
           duration: duration,
           duration_unit: duration_unit
         },
         %{
           time_scale_unit: time_scale_unit,
           overflow: overflow,
           log_lines: log_lines,
           log_count: log_count,
           status_codes: status_codes,
           request_counts: request_counts,
           request_times: request_times
         } ->
        overflow = overflow || log_count > @max_log_lines
        truncated_time = DateTime.truncate(time, :second)

        truncated_time =
          case time_scale_unit do
            :minute -> truncated_time
            :hour -> %{truncated_time | minute: 0}
          end

        normalized_duration =
          case duration_unit do
            "ms" -> duration
            _ -> duration * 1000
          end

        %{
          time_scale_unit: time_scale_unit,
          overflow: overflow,
          log_lines: case overflow do
            true -> log_lines
            false -> log_lines ++ [log_line]
          end,
          log_count: log_count + 1,
          status_codes:
            Map.merge(status_codes, %{label => %{status_code => 1}}, fn _, a, b ->
              Map.merge(a, b, fn _, i, j -> i + j end)
            end),
          request_counts:
            Map.merge(request_counts, %{label => %{truncated_time => 1}}, fn _, a, b ->
              Map.merge(a, b, fn _, i, j -> i + j end)
            end),
          request_times:
            Map.merge(
              request_times,
              %{label => %{truncated_time => normalized_duration}},
              fn _, a, b ->
                Map.merge(a, b, fn _, i, j -> (i + j) / 2 end)
              end
            )
        }
      end
    )
  end

  def read(_start_at, _end_at, _application, _type), do: %{}

  defp log_stream(start_at, end_at) do
    log_dates(DateTime.to_date(start_at), DateTime.to_date(end_at))
    |> Enum.map(&LogRotate.path/1)
    |> Enum.filter(fn path -> File.exists?(path) end)
    |> Enum.map(&File.stream!/1)
    |> Stream.concat()
    |> Stream.drop_while(fn log ->
      case DateTime.from_iso8601(String.split(log, " ") |> List.first()) do
        {:ok, log_time, _offset} ->
          DateTime.compare(log_time, start_at) == :lt

        _ ->
          true
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

  defp parse_request_log(log_line) do
    case Regex.run(@request_log_regex, log_line) do
      nil ->
        nil

      [
        log_line,
        raw_time,
        request_id,
        application,
        method,
        path,
        _state,
        status_code,
        duration,
        duration_unit
      ] ->
        with {:ok, time, _offset} <- DateTime.from_iso8601(raw_time) do
          %{
            log_line: log_line,
            time: time,
            label: String.slice("#{application} - #{method} #{path}", 0..70),
            request_id: request_id,
            application: application,
            method: method,
            path: path,
            status_code: status_code,
            duration: String.to_integer(duration),
            duration_unit: duration_unit
          }
        end
    end
  end

  defp log_dates(start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      []
    else
      [start_date | log_dates(Date.add(start_date, 1), end_date)]
    end
  end

  defp time_scale_unit(start_at, end_at) do
    case DateTime.diff(end_at, start_at, :second) > 60 * 60 * 24 do
      true -> :hour
      false -> :minute
    end
  end
end
