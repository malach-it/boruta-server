defmodule BorutaAdminWeb.LogsControllerTest do
  use BorutaAdminWeb.ConnCase

  alias BorutaAuth.LogRotate

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
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["logs:read:all"]
    test "return today's logs", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(Date.utc_today()))

      before_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(-1 * 20 * 60, :second) |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      log_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      after_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      File.write!(LogRotate.path(Date.utc_today()), Enum.join([before_lines, log_lines, after_lines]))

      start_at = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()
      end_at = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at})

      assert response(conn, 200) == log_lines

      File.rm!(LogRotate.path(Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines before start_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(Date.utc_today()))

      before_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(-1 * 20 * 60, :second) |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      log_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      File.write!(LogRotate.path(Date.utc_today()), Enum.join([before_lines, log_lines]))

      start_at = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()
      end_at = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at})

      assert response(conn, 200) == log_lines

      File.rm!(LogRotate.path(Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines after end_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(Date.utc_today()))

      log_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      after_lines = Enum.map_join(1..10, "", fn i ->
        log_time = DateTime.utc_now() |> DateTime.add(i * 60, :second)

        "#{DateTime.to_iso8601(log_time)} test log line\n"
      end)
      File.write!(LogRotate.path(Date.utc_today()), Enum.join([log_lines, after_lines]))

      start_at = DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()
      end_at = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at})

      assert response(conn, 200) == log_lines

      File.rm!(LogRotate.path(Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "return multiple day logs", %{conn: conn} do
      first_day = Date.utc_today() |> Date.add(-10)
      second_day = Date.utc_today() |> Date.add(-8)

      File.mkdir("./log")
      File.rm(LogRotate.path(first_day))
      File.rm(LogRotate.path(second_day))

      [first_day_log_lines, second_day_log_lines] = Enum.map([10, 8], fn day_shift ->
        Enum.map_join(1..10, "", fn i ->
          log_time = DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * day_shift, :second) |> DateTime.add(i * 60, :second)
          "#{DateTime.to_iso8601(log_time)} test log line\n"
        end)
      end)
      File.write!(LogRotate.path(first_day), first_day_log_lines)
      File.write!(LogRotate.path(second_day), second_day_log_lines)

      start_at = DateTime.utc_now() |> DateTime.add(-1 * 10 * 24 * 3600, :second) |> DateTime.to_iso8601()
      end_at = DateTime.utc_now() |> DateTime.to_iso8601()
      conn = get(conn, Routes.admin_logs_path(conn, :index), %{start_at: start_at, end_at: end_at})

      assert response(conn, 200) == Enum.join([first_day_log_lines, second_day_log_lines], "")

      File.rm(LogRotate.path(first_day))
      File.rm(LogRotate.path(second_day))
    end
  end
end
