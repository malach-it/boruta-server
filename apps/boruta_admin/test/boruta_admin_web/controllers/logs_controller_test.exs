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
      log_line = "test log line"
      File.mkdir("./log")
      File.rm(LogRotate.path(Date.utc_today()))
      File.write!(LogRotate.path(Date.utc_today()), log_line)

      conn = get(conn, Routes.admin_logs_path(conn, :index))

      assert response(conn, 200) == log_line

      File.rm!(LogRotate.path(Date.utc_today()))
    end
  end
end
