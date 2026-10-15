defmodule BorutaAuth.LogRotateTest do
  use ExUnit.Case, async: false

  test "does not create the log directory when file logging is disabled" do
    previous_config = Application.get_env(:boruta_auth, BorutaAuth.LogRotate)
    log_directory = Path.join(System.tmp_dir!(), "boruta-disabled-file-logging")

    File.rm_rf!(log_directory)

    Application.put_env(:boruta_auth, BorutaAuth.LogRotate,
      enabled: false,
      log_directory: log_directory,
      max_retention_days: 60
    )

    on_exit(fn ->
      Application.put_env(:boruta_auth, BorutaAuth.LogRotate, previous_config)
      File.rm_rf!(log_directory)
    end)

    assert :ok = BorutaAuth.LogRotate.rotate()
    refute File.exists?(log_directory)
  end
end
