defmodule BorutaAdminWeb.LogsControllerTest do
  use BorutaAdminWeb.ConnCase

  alias BorutaAuth.LogRotate

  @request_log_lines [
    "request_id=Fwd0KILP8T4HsB4AAA3h [info] boruta_web POST /oauth/introspect - sent 200 from 0.0.0.0 in 2ms",
    "request_id=FweNn-2vW71XZiUAAljD [info] boruta_web GET /oauth/authorize - sent 200 from 0.0.0.0 in 16ms",
    "request_id=FweINeYU7G053agAAApG [info] boruta_web POST /oauth/token - sent 401 from 0.0.0.0 in 952µs"
  ]

  @business_log_lines [
    "request_id=Fwh6kT_QfosEujUAAADC [info] boruta_web authorization authorize - success client_id=6a2f41a3-c54c-fce8-32d2-0324e1c32e20 sub=9b15219f-30a9-4a98-8c2e-296d0a53c638 type=token access_token=QjkypPrdh6iFsgYmp40wzqxTPs6JOFDRrRJXxKPNK0Kjp6LAF83tpHtqtCKlkzYByu3YvhwC1JJZbXBia0cwUF expires_in=3600",
    "request_id=Fwh6kXSdqY_TBZEAAA3B [info] boruta_web authorization introspect - success client_id=6a2f41a3-c54c-fce8-32d2-0324e1c32e20 sub=7133cbcc-3f1f-448b-bc5a-8f551a3d3883 access_token=QjkypPrdh6iFsgYmp40wzqxTPs6JOFDRrRJXxKPNK0Kjp6LAF83tpHtqtCKlkzYByu3YvhwC1JJZbXBia0cwUF active=true",
    "request_id=Fwh6liuATTbaqC4AAAJm [info] boruta_web authorization introspect - failure client_id=6a2f41a3-c54c-fce8-32d2-0324e1c32e20 sub=7133cbcc-3f1f-448b-bc5a-8f551a3d3883 access_token=QjkypPrdh6iFsgYmp40wzqxTPs6JOFDRrRJXxKPNK0Kjp6LAF83tpHtqtCKlkzYByu3YvhwC1JJZbXBia0cwUF active=true"
  ]

  @gateway_business_log_lines [
    "request_id=Fwh6kT_QfosEujUAAADC [info] boruta_gateway gateway proxy - success upstream_id=upstream upstream_host=example.com upstream_port=443 request_time=1200 gateway_time=200 upstream_time=1000",
    "request_id=Fwh6kXSdqY_TBZEAAA3B [info] boruta_gateway gateway proxy - success upstream_id=upstream upstream_host=example.com upstream_port=443 request_time=2400 gateway_time=400 upstream_time=2000"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # TODO test sub restriction
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

  describe "index requesting requests logs" do
    @tag authorized: ["logs:read:all"]
    test "return today's logs", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      before_lines =
        request_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        request_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        request_log_line_serie(fn i -> DateTime.utc_now() |> DateTime.add(i * 60, :second) end)

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
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "request"
        })

      assert %{
               "time_scale_unit" => "second",
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

    @tag :skip
    test "filter logs"

    @tag authorized: ["logs:read:all"]
    test "groups direct post requests by route in dashboard stats", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      log_time = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      direct_post_lines = [
        "#{DateTime.to_iso8601(log_time)} request_id=direct-post-1 [info] boruta_web POST /openid/direct_post/code-1 - sent 200 from 0.0.0.0 in 2ms",
        "#{DateTime.to_iso8601(log_time)} request_id=direct-post-2 [info] boruta_web POST /openid/direct_post/code-2 - sent 302 from 0.0.0.0 in 4ms"
      ]

      File.write!(
        LogRotate.path(:boruta_web, :request, Date.utc_today()),
        Enum.join(direct_post_lines, "\n") <> "\n"
      )

      start_at = log_time |> DateTime.add(-1, :second) |> DateTime.to_iso8601()
      end_at = log_time |> DateTime.add(1, :second) |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "request"
        })

      direct_post_label = "boruta_web - POST /openid/direct_post/:code_id"

      assert %{
               "labels" => [^direct_post_label],
               "log_lines" => ^direct_post_lines,
               "log_count" => 2,
               "status_codes" => %{
                 ^direct_post_label => %{
                   "200" => 1,
                   "302" => 1
                 }
               },
               "request_counts" => %{
                 ^direct_post_label => request_counts
               }
             } = json_response(conn, 200)

      assert Enum.sum(Map.values(request_counts)) == 2

      File.rm!(LogRotate.path(:boruta_web, :request, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines before start_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :request, Date.utc_today()))

      before_lines =
        request_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        request_log_line_serie(fn i ->
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
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "request"
        })

      assert %{
               "time_scale_unit" => "second",
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
        request_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        request_log_line_serie(fn i ->
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
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "request"
        })

      assert %{
               "time_scale_unit" => "second",
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
      cleanup_log_files(:boruta_web, :request, first_day, Date.utc_today())

      [first_day_log_lines, second_day_log_lines] =
        Enum.map([10, 8], fn day_shift ->
          request_log_line_serie(fn i ->
            DateTime.utc_now()
            |> DateTime.add(-1 * 24 * 3600 * day_shift, :second)
            |> DateTime.add(i * 60, :second)
          end)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :request, first_day),
        Enum.join(first_day_log_lines, "\n")
      )

      File.write!(
        LogRotate.path(:boruta_web, :request, second_day),
        Enum.join(second_day_log_lines, "\n")
      )

      start_at = first_day |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> DateTime.to_iso8601()

      end_at =
        second_day
        |> Date.add(1)
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "request"
        })

      log_lines = first_day_log_lines ++ second_day_log_lines

      assert %{
               "time_scale_unit" => "day",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 60
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :request, first_day))
      File.rm!(LogRotate.path(:boruta_web, :request, second_day))
    end
  end

  describe "index requesting business events logs" do
    @tag authorized: ["logs:read:all"]
    test "return today's logs", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :business, Date.utc_today()))

      before_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        business_log_line_serie(fn i -> DateTime.utc_now() |> DateTime.add(i * 60, :second) end)

      File.write!(
        LogRotate.path(:boruta_web, :business, Date.utc_today()),
        Enum.map_join([before_lines, log_lines, after_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "business"
        })

      assert %{
               "time_scale_unit" => "second",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :business, Date.utc_today()))
    end

    @tag :skip
    test "compute business event counts"

    @tag :skip
    test "compute counts"

    @tag :skip
    test "filter logs"

    @tag authorized: ["logs:read:all"]
    test "exposes gateway times", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_gateway, :business, Date.utc_today()))

      log_time =
        DateTime.utc_now()
        |> DateTime.add(-1 * 10 * 60, :second)
        |> DateTime.truncate(:second)

      log_lines =
        Enum.map(@gateway_business_log_lines, fn log ->
          "#{DateTime.to_iso8601(log_time)} #{log}"
        end)

      File.write!(
        LogRotate.path(:boruta_gateway, :business, Date.utc_today()),
        Enum.join(log_lines, "\n")
      )

      start_at = log_time |> DateTime.add(-1, :second) |> DateTime.to_iso8601()
      end_at = DateTime.utc_now() |> DateTime.to_iso8601()
      timestamp = Calendar.strftime(log_time, "%Y-%m-%d %H:%M:%SZ")

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_gateway",
          type: "business"
        })

      assert %{
               "gateway_times" => %{
                 "request time" => %{^timestamp => request_time},
                 "gateway time" => %{^timestamp => gateway_time},
                 "upstream time" => %{^timestamp => upstream_time}
               }
             } = json_response(conn, 200)

      assert_in_delta request_time, 1.8, 0.001
      assert_in_delta gateway_time, 0.3, 0.001
      assert_in_delta upstream_time, 1.5, 0.001

      File.rm!(LogRotate.path(:boruta_gateway, :business, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines before start_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :business, Date.utc_today()))

      before_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 20 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      log_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :business, Date.utc_today()),
        Enum.map_join([before_lines, log_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "business"
        })

      assert %{
               "time_scale_unit" => "second",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :business, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "skips lines after end_at", %{conn: conn} do
      File.mkdir("./log")
      File.rm(LogRotate.path(:boruta_web, :business, Date.utc_today()))

      log_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now()
          |> DateTime.add(-1 * 10 * 60, :second)
          |> DateTime.add(i * 60, :second)
        end)

      after_lines =
        business_log_line_serie(fn i ->
          DateTime.utc_now() |> DateTime.add(i * 60, :second)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :business, Date.utc_today()),
        Enum.map_join([log_lines, after_lines], fn serie ->
          Enum.join(serie, "\n") <> "\n"
        end) <> "\n"
      )

      start_at =
        DateTime.utc_now() |> DateTime.add(-1 * 10 * 60, :second) |> DateTime.to_iso8601()

      end_at = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "business"
        })

      assert %{
               "time_scale_unit" => "second",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 30
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :business, Date.utc_today()))
    end

    @tag authorized: ["logs:read:all"]
    test "return multiple day logs", %{conn: conn} do
      first_day = Date.utc_today() |> Date.add(-10)
      second_day = Date.utc_today() |> Date.add(-8)

      File.mkdir("./log")
      cleanup_log_files(:boruta_web, :business, first_day, Date.utc_today())

      [first_day_log_lines, second_day_log_lines] =
        Enum.map([10, 8], fn day_shift ->
          business_log_line_serie(fn i ->
            DateTime.utc_now()
            |> DateTime.add(-1 * 24 * 3600 * day_shift, :second)
            |> DateTime.add(i * 60, :second)
          end)
        end)

      File.write!(
        LogRotate.path(:boruta_web, :business, first_day),
        Enum.join(first_day_log_lines, "\n")
      )

      File.write!(
        LogRotate.path(:boruta_web, :business, second_day),
        Enum.join(second_day_log_lines, "\n")
      )

      start_at = first_day |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> DateTime.to_iso8601()

      end_at =
        second_day
        |> Date.add(1)
        |> DateTime.new!(~T[00:00:00], "Etc/UTC")
        |> DateTime.to_iso8601()

      conn =
        get(conn, Routes.admin_logs_path(conn, :index), %{
          start_at: start_at,
          end_at: end_at,
          application: "boruta_web",
          type: "business"
        })

      log_lines = first_day_log_lines ++ second_day_log_lines

      assert %{
               "time_scale_unit" => "day",
               "overflow" => false,
               "log_lines" => ^log_lines,
               "log_count" => 60
             } = json_response(conn, 200)

      File.rm!(LogRotate.path(:boruta_web, :business, first_day))
      File.rm!(LogRotate.path(:boruta_web, :business, second_day))
    end
  end

  defp request_log_line_serie(fun) do
    Enum.flat_map(1..10, fn i ->
      log_time = fun.(i)

      Enum.map(@request_log_lines, fn log -> "#{DateTime.to_iso8601(log_time)} #{log}" end)
    end)
  end

  defp cleanup_log_files(application, type, start_date, end_date) do
    start_date
    |> Date.range(end_date)
    |> Enum.each(fn date ->
      application
      |> LogRotate.path(type, date)
      |> File.rm()
    end)
  end

  defp business_log_line_serie(fun) do
    Enum.flat_map(1..10, fn i ->
      log_time = fun.(i)

      Enum.map(@business_log_lines, fn log -> "#{DateTime.to_iso8601(log_time)} #{log}" end)
    end)
  end
end
