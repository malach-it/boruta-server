defmodule BorutaAdmin.LogsTest do
  use ExUnit.Case, async: false

  alias BorutaAdmin.Logs
  alias BorutaAuth.LogRotate

  describe "read/5" do
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
