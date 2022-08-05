defmodule BorutaAdminWeb.LogsControllerTest do
  use BorutaAdminWeb.ConnCase

  alias BorutaAuth.LogRotate

  @log_lines [
    "request_id=Fwd0KILP8T4HsB4AAA3h [info] boruta_web POST /oauth/introspect - sent 200 in 2ms",
    "request_id=FweNn-2vW71XZiUAAljD [info] boruta_web GET /oauth/authorize - sent 200 in 16ms",
    "request_id=FweINeYU7G053agAAApG [info] boruta_web POST /oauth/token - sent 401 in 952µs"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_logs_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_logs_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["logs:read:all"]
    test "return today's logs", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      before_lines =
        log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        log_line_serie(fn i -> DateTime.utc_now() |> DateTime.add(i * 60, :second) end)

      File.write!(
        LogRotate.path(:boruta_web, :request, Date.utc_today()),
        Enum.map_join([before_lines, log_lines, after_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at, application: "boruta_web", type: "request"})

      assert %{
               "time_scale_unit" => "minute",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :request, Date.utc_today()))
    end

    @tag :skip
    test "compute request times"

    @tag :skip
    test "compute request counts"

    @tag :skip
    test "compute status codes"

    @tag authorized: ["logs:read:all"]
    test "skips lines before start_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      before_lines =
        log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :request, Date.utc_today()),
        Enum.map_join([before_lines, log_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at, application: "boruta_web", type: "request"})

      assert %{
               "time_scale_unit" => "minute",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :request, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines after end_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      log_lines =
        log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        log_line_serie(fn i ->
          DateTime.utc_now() |> DateTime.add(i * 60, :second)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :request, Date.utc_today()),
        Enum.map_join([log_lines, after_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at, application: "boruta_web", type: "request"})

      assert %{
               "time_scale_unit" => "minute",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :request, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "return multiple day logs", %{conn: conn} do
      first_day = Date.utc_today() |> Date.add(-10)
      second_day = Date.utc_today() |> Date.add(-8)

      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, first_day))
      File.rm(LogRotate.path(:boruta_web, :request, second_day))

      [first_day_log_lines, second_day_log_lines] =
        Enum.map([10, 8], fn day_shift ->
          log_line_serie(fn i ->
            DateTime.utc_now()
            |> DateTime.add(-1 * 24 * 3600 * day_shift, :second)
            |> DateTime.add(i * 60, :second)
          end)
        end)

      File.write!(LogRotate.path(:boruta_web, :request, first_day), Enum.join(first_day_log_lines, "\n"))
      File.write!(LogRotate.path(:boruta_web, :request, second_day), Enum.join(second_day_log_lines, "\n"))

      start_at =
        DateTime.utc_now()
        |> DateTime.add(-1 * 10 * 24 * 3600 - 1, :second)
        |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at, application: "boruta_web", type: "request"})

      log_lines = first_day_log_lines ++ second_day_log_lines
      assert %{
               "time_scale_unit" => "hour",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 60
             } = json_response(conn, 200)

      File.rm(LogRotate.path(:boruta_web, :request, first_day))
      File.rm(LogRotate.path(:boruta_web, :request, second_day))
    end
  end

  defp log_line_serie(fun) do
    Enum.flat_map(1..10, fn i ->
      log_time = fun.(i)

      Enum.map(@log_lines, fn log -> "#{DateTime.to_iso8601(log_time)} #{log}" end)
    end)
  end
end
