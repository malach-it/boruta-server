defmodule BorutaAdmin.LogsTest do
  use ExUnit.Case, async: false

  alias BorutaAdmin.Logs
  alias BorutaAuth.LogRotate

  describe "read/5" do
    test "uses the configured adapter" do
      previous_config = Application.get_env(:boruta_admin, Logs)

      Application.put_env(:boruta_admin, Logs,
        adapter: BorutaAdmin.LogsTest.Adapter,
        adapter_options: [test_pid: self()]
      )

      on_exit(fn -> restore_logs_config(previous_config) end)

      stats =
        Logs.read(
          ~U[2099-01-03 00:00:00Z],
          ~U[2099-01-04 00:00:00Z],
          :boruta_web,
          :request,
          %{}
        )

      assert stats.log_count == 1
      assert stats.aggregated

      assert_received {:stream, ~U[2099-01-03 00:00:00Z], ~U[2099-01-04 00:00:00Z], :boruta_web,
                       :request, %{}}

      assert_received {:aggregate, ~U[2099-01-03 00:00:00Z], ~U[2099-01-04 00:00:00Z],
                       :boruta_web, :request, %{}}

      assert Logs.earliest_at(:boruta_web, :request) == ~U[2098-01-01 00:00:00Z]
      assert_received {:earliest_at, :boruta_web, :request}
    end

    test "parses privacy-preserving business events without attributes" do
      date = ~D[2099-01-01]
      path = LogRotate.path(:boruta_admin, :business, date)

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-01T00:00:01Z request_id=request-id [info] boruta_admin role update - success\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-01 00:00:00Z],
          ~U[2099-01-02 00:00:00Z],
          :boruta_admin,
          :business,
          %{}
        )

      assert [event] = stats.events

      assert %{
               time: ~U[2099-01-01 00:00:01Z],
               label: "boruta_admin - role update",
               status: "success",
               attributes: %{}
             } = event
    end

    test "decodes form-encoded admin business event attributes" do
      date = ~D[2099-01-01]
      path = LogRotate.path(:boruta_admin, :business, date)

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-01T00:00:01Z request_id=request-id [info] boruta_admin client update - success supported_grant_types=authorization_code%2Crefresh_token template_type=login+template%0Aforged%3Dtrue\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-01 00:00:00Z],
          ~U[2099-01-02 00:00:00Z],
          :boruta_admin,
          :business,
          %{}
        )

      assert [event] = stats.events

      assert event.attributes == %{
               "supported_grant_types" => "authorization_code,refresh_token",
               "template_type" => "login template\nforged=true"
             }
    end

    test "does not decode attributes from other applications" do
      date = ~D[2099-01-01]
      path = LogRotate.path(:boruta_web, :business, date)

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-01T00:00:01Z request_id=request-id [info] boruta_web authorization authorize - success value=literal%2Cvalue\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-01 00:00:00Z],
          ~U[2099-01-02 00:00:00Z],
          :boruta_web,
          :business,
          %{}
        )

      assert [event] = stats.events
      assert event.attributes == %{"value" => "literal%2Cvalue"}
    end

    test "parses a microsecond request duration without engine-dependent backtracking" do
      date = ~D[2099-01-03]
      path = LogRotate.path(:boruta_web, :request, date)
      time = ~U[2099-01-03 12:00:00Z]

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-03T12:00:00.000Z request_id=request-id [info] boruta_web OPTIONS /oauth/revoke - sent 204 from 127.0.0.1 in 110µs\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-03 00:00:00Z],
          ~U[2099-01-04 00:00:00Z],
          :boruta_web,
          :request,
          %{}
        )

      assert stats.log_count == 1

      assert_in_delta get_in(
                        stats,
                        [:request_times, "boruta_web - OPTIONS /oauth/revoke", time]
                      ),
                      0.11,
                      0.000_001
    end

    test "filters request log messages by exact text" do
      date = ~D[2099-01-03]
      path = LogRotate.path(:boruta_web, :request, date)

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-03T12:00:00Z request_id=first [info] boruta_web GET /oauth/authorize - sent 200 from 127.0.0.1 in 1ms\n" <>
          "2099-01-03T12:00:01Z request_id=second [info] boruta_web POST /oauth/token - sent 200 from 127.0.0.1 in 1ms\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-03 00:00:00Z],
          ~U[2099-01-04 00:00:00Z],
          :boruta_web,
          :request,
          %{text: "/oauth/authorize"}
        )

      assert stats.log_count == 1
      assert [log_line] = stats.log_lines
      assert log_line =~ "/oauth/authorize"

      non_matching_stats =
        Logs.read(
          ~U[2099-01-03 00:00:00Z],
          ~U[2099-01-04 00:00:00Z],
          :boruta_web,
          :request,
          %{text: "/oauth/AUTHORIZE"}
        )

      assert non_matching_stats.log_count == 0
    end

    test "filters business event log messages by exact text" do
      date = ~D[2099-01-03]
      path = LogRotate.path(:boruta_web, :business, date)

      File.mkdir_p!("./log")

      File.write!(
        path,
        "2099-01-03T12:00:00Z request_id=first [info] boruta_web authorization authorize - success client_id=first\n" <>
          "2099-01-03T12:00:01Z request_id=second [info] boruta_web authorization introspect - success client_id=second\n"
      )

      on_exit(fn -> File.rm(path) end)

      stats =
        Logs.read(
          ~U[2099-01-03 00:00:00Z],
          ~U[2099-01-04 00:00:00Z],
          :boruta_web,
          :business,
          %{text: "authorization introspect"}
        )

      assert stats.log_count == 1
      assert [log_line] = stats.log_lines
      assert log_line =~ "authorization introspect"
    end

    test "rejects requests whose total log file size exceeds the limit" do
      first_date = ~D[2099-01-01]
      second_date = ~D[2099-01-02]
      first_path = LogRotate.path(:boruta_web, :request, first_date)
      second_path = LogRotate.path(:boruta_web, :request, second_date)
      previous_config = Application.get_env(:boruta_admin, Logs)

      File.mkdir_p!("./log")
      File.write!(first_path, "123456\n")
      File.write!(second_path, "abcdef\n")
      Application.put_env(:boruta_admin, Logs, max_file_size: 10)

      on_exit(fn ->
        File.rm(first_path)
        File.rm(second_path)
        restore_logs_config(previous_config)
      end)

      assert_raise Logs.FileTooLargeError,
                   "Requested for more than 10 bytes of logs, could not perform the request.",
                   fn ->
                     Logs.read(
                       ~U[2099-01-01 00:00:00Z],
                       ~U[2099-01-03 00:00:00Z],
                       :boruta_web,
                       :request,
                       %{}
                     )
                   end
    end
  end

  defp restore_logs_config(nil) do
    Application.delete_env(:boruta_admin, Logs)
  end

  defp restore_logs_config(config) do
    Application.put_env(:boruta_admin, Logs, config)
  end
end

defmodule BorutaAdmin.LogsTest.Adapter do
  @behaviour BorutaAdmin.Logs.Adapter

  @impl true
  def earliest_at(application, type, options) do
    send(Keyword.fetch!(options, :test_pid), {:earliest_at, application, type})
    ~U[2098-01-01 00:00:00Z]
  end

  @impl true
  def stream(start_at, end_at, application, type, query, options) do
    send(
      Keyword.fetch!(options, :test_pid),
      {:stream, start_at, end_at, application, type, query}
    )

    [
      "2099-01-03T12:00:00.000Z request_id=request-id [info] boruta_web GET /oauth/authorize - sent 200 from 127.0.0.1 in 1ms"
    ]
  end

  @impl true
  def aggregate(start_at, end_at, application, type, query, stats, options) do
    send(
      Keyword.fetch!(options, :test_pid),
      {:aggregate, start_at, end_at, application, type, query}
    )

    Map.put(stats, :aggregated, true)
  end
end
