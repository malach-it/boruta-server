defmodule BorutaAdmin.Logs.FileTooLargeError do
  @enforce_keys [:message]
  defexception [:message, plug_status: 422]

  @type t :: %__MODULE__{
          message: String.t()
        }

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end

  def message(exception) do
    exception.message
  end
end

defmodule BorutaAdmin.Logs do
  @moduledoc false

  alias BorutaAuth.LogRotate

  @max_file_size 100_000_000
  @max_log_lines 10_000
  @request_log_regex ~r/(\d{4}-\d{2}-\d{2}T[^Z]+Z) request_id=([^\s]+) \[info\] ([^\s]+) (\w+) ([^\s]+) - (\w+) (\d{3}) from ((\d+\.?){4}) in (\d+)(\w+)/
  @business_event_log_regex ~r/(\d{4}-\d{2}-\d{2}T[^Z]+Z) request_id=([^\s]+) \[info\] ([^\s]+) (\w+) (\w+) - (\w+)(( ([^\=]+)\=((\".+\")|([^\s]+)))+)/

  @spec read(
          start_at :: DateTime.t(),
          end_at :: DateTime.t(),
          application :: atom(),
          type :: atom(),
          query :: map()
        ) :: Enumerable.t()
  # credo:disable-for-next-line
  def read(start_at, end_at, application, :request = type, query) do
    time_scale_unit = time_scale_unit(start_at, end_at)

    log_stream(start_at, end_at, application, type)
    |> Stream.map(&parse_request_log/1)
    |> Stream.reject(&is_nil/1)
    |> apply_request_filters(query)
    |> Enum.reduce(
      %{
        time_scale_unit: time_scale_unit,
        overflow: false,
        log_lines: [],
        log_count: 0,
        status_codes: %{},
        request_counts: %{},
        request_times: %{},
        labels: []
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
           request_times: request_times,
           labels: labels
         } ->
        overflow = overflow || log_count >= @max_log_lines
        truncated_time = DateTime.truncate(time, :second)

        truncated_time =
          case time_scale_unit do
            :second -> truncated_time
            :minute -> %{truncated_time | second: 0}
            :hour -> %{truncated_time | second: 0, minute: 0}
          end

        normalized_duration =
          case duration_unit do
            "ms" -> duration
            "µs" -> duration / 1000
          end

        %{
          time_scale_unit: time_scale_unit,
          overflow: overflow,
          log_lines:
            case overflow do
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
            ),
          labels:
            case Enum.member?(labels, label) do
              false -> [label | labels] |> Enum.sort()
              true -> labels
            end
        }
      end
    )
  end

  # credo:disable-for-next-line
  def read(start_at, end_at, application, :business = type, query) do
    time_scale_unit = time_scale_unit(start_at, end_at)

    log_stream(start_at, end_at, application, type)
    |> Stream.map(&parse_business_log/1)
    |> Stream.reject(&is_nil/1)
    |> apply_business_filters(query)
    |> Enum.reduce(
      %{
        time_scale_unit: time_scale_unit,
        overflow: false,
        log_lines: [],
        log_count: 0,
        counts: %{},
        business_event_counts: %{},
        domains: [],
        actions: []
      },
      fn %{
           log_line: log_line,
           time: time,
           label: label,
           status: status,
           domain: domain,
           action: action
         },
         %{
           time_scale_unit: time_scale_unit,
           overflow: overflow,
           log_lines: log_lines,
           log_count: log_count,
           counts: counts,
           business_event_counts: business_event_counts,
           domains: domains,
           actions: actions
         } ->
        overflow = overflow || log_count >= @max_log_lines
        truncated_time = DateTime.truncate(time, :second)

        truncated_time =
          case time_scale_unit do
            :second -> truncated_time
            :minute -> %{truncated_time | second: 0}
            :hour -> %{truncated_time | second: 0, minute: 0}
          end

        %{
          time_scale_unit: time_scale_unit,
          overflow: overflow,
          log_lines:
            case overflow do
              true -> log_lines
              false -> log_lines ++ [log_line]
            end,
          log_count: log_count + 1,
          business_event_counts:
            Map.merge(business_event_counts, %{label => %{truncated_time => 1}}, fn _, a, b ->
              Map.merge(a, b, fn _, i, j -> i + j end)
            end),
          counts:
            Map.merge(counts, %{label => %{status => 1}}, fn _, a, b ->
              Map.merge(a, b, fn _, i, j -> i + j end)
            end),
          domains:
            case Enum.member?(domains, domain) do
              false -> [domain | domains] |> Enum.sort()
              true -> domains
            end,
          actions:
            case Enum.member?(actions, action) do
              false -> [action | actions] |> Enum.sort()
              true -> actions
            end
        }
      end
    )
  end

  def read(_start_at, _end_at, _application, _type), do: %{}

  defp log_stream(start_at, end_at, application, type) do
    paths =
      log_dates(DateTime.to_date(start_at), DateTime.to_date(end_at))
      |> Enum.map(&LogRotate.path(application, type, &1))
      |> Enum.filter(&File.exists?/1)

    if Enum.reduce(paths, 0, fn path, _acc -> File.stat!(path).size end) > @max_file_size do
      raise BorutaAdmin.Logs.FileTooLargeError,
            "Requested for more than #{@max_file_size} bytes of logs, could not perform the request."
    end

    paths
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
        _,
        ip_address,
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
            ip_address: ip_address,
            duration: String.to_integer(duration),
            duration_unit: duration_unit
          }
        end
    end
  end

  def apply_request_filters(request_stream, query) do
    Enum.reduce(query, request_stream, fn
      {_key, nil}, stream ->
        stream

      {_key, ""}, stream ->
        stream

      {key, value}, stream when key in [:label] ->
        Stream.filter(stream, fn
          %{^key => ^value} -> true
          _ -> false
        end)

      _, stream ->
        stream
    end)
  end

  def apply_business_filters(request_stream, query) do
    Enum.reduce(query, request_stream, fn
      {_key, nil}, stream ->
        stream

      {_key, ""}, stream ->
        stream

      {key, value}, stream when key in [:domain, :action] ->
        Stream.filter(stream, fn
          %{^key => ^value} -> true
          _ -> false
        end)

      _, stream ->
        stream
    end)
  end

  defp parse_business_log(log_line) do
    case Regex.run(@business_event_log_regex, log_line) do
      nil ->
        nil

      [
        log_line,
        raw_time,
        request_id,
        application,
        domain,
        action,
        status | _raw_attributes
      ] ->
        with {:ok, time, _offset} <- DateTime.from_iso8601(raw_time) do
          %{
            log_line: log_line,
            time: time,
            request_id: request_id,
            label: String.slice("#{application} - #{domain} #{action}", 0..70),
            application: application,
            domain: String.slice("#{application} - #{domain}", 0..70),
            action: String.slice("#{application} - #{domain} #{action}", 0..70),
            status: status
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
    case DateTime.diff(end_at, start_at, :second) do
      duration when duration < 60 * 60 -> :second
      duration when duration < 60 * 60 * 24 -> :minute
      _duration -> :hour
    end
  end
end
