defmodule BorutaAuth.SchedulerTest do
  use ExUnit.Case, async: true

  test "log rotation runs on every clustered node" do
    scheduler_config = Application.fetch_env!(:boruta_auth, BorutaAuth.Scheduler)

    assert [
             schedule: "@daily",
             task: {BorutaAuth.LogRotate, :rotate, []},
             run_strategy: {Quantum.RunStrategy.All, :cluster}
           ] in scheduler_config[:jobs]
  end
end
