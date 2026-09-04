defmodule BorutaAdmin.ReleaseCommandTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  setup do
    test_directory =
      Path.join(
        System.tmp_dir!(),
        "boruta-cli-release-command-#{System.unique_integer([:positive])}"
      )

    release_root = Path.join(test_directory, "release")
    bin_directory = Path.join(release_root, "bin")
    File.mkdir_p!(bin_directory)

    wrapper =
      Path.expand("../../../../rel/boruta-cli.eex", __DIR__)
      |> EEx.eval_file(assigns: [release: %{name: :boruta}])

    wrapper_path = Path.join(bin_directory, "boruta-cli")
    release_path = Path.join(bin_directory, "boruta")
    capture_path = Path.join(test_directory, "capture")

    File.write!(wrapper_path, wrapper)
    File.chmod!(wrapper_path, 0o755)

    File.write!(
      release_path,
      """
      #!/bin/sh
      if [ "$1" = "pid" ]; then
        if [ -n "${BORUTA_TEST_DISTRIBUTION:-}" ] && [ "$RELEASE_DISTRIBUTION" != "$BORUTA_TEST_DISTRIBUTION" ]; then
          exit 1
        fi
        exit "${BORUTA_TEST_PID_STATUS:-1}"
      fi
      printf '%s\n' "$@" > "$BORUTA_TEST_CAPTURE"
      if [ "$1" = "rpc" ]; then
        printf '%s' "${BORUTA_TEST_RPC_OUTPUT:-}"
        exit "${BORUTA_TEST_RPC_STATUS:-0}"
      fi
      """
    )

    File.chmod!(release_path, 0o755)
    on_exit(fn -> File.rm_rf!(test_directory) end)

    {:ok, wrapper: wrapper_path, capture: capture_path}
  end

  test "uses RPC when the configured release node is reachable", context do
    env = [
      {"RELEASE_NODE", "boruta@node"},
      {"RELEASE_COOKIE", "cookie"},
      {"BORUTA_TEST_DISTRIBUTION", "sname"},
      {"BORUTA_TEST_PID_STATUS", "0"},
      {"BORUTA_TEST_CAPTURE", context.capture}
    ]

    assert {"", 0} =
             System.cmd(context.wrapper, ["role", "show", "identifier'with-quote"], env: env)

    assert ["rpc", expression] = context.capture |> File.read!() |> String.split("\n", trim: true)

    assert expression ==
             ~s|BorutaAdmin.ReleaseCommand.remote(Enum.map(["726f6c65","73686f77","6964656e74696669657227776974682d71756f7465"], &Base.decode16!(&1, case: :mixed)))|
  end

  test "falls back to eval when the configured release node is unreachable", context do
    env = [
      {"RELEASE_NODE", "boruta@node"},
      {"RELEASE_COOKIE", "cookie"},
      {"BORUTA_TEST_PID_STATUS", "1"},
      {"BORUTA_TEST_CAPTURE", context.capture}
    ]

    assert {"", 0} = System.cmd(context.wrapper, ["role", "index"], env: env)

    assert ["eval", "BorutaAdmin.ReleaseCommand.main(System.argv())", "role", "index"] =
             context.capture |> File.read!() |> String.split("\n", trim: true)
  end

  test "turns the remote error marker into a non-zero exit without exposing it", context do
    env = [
      {"RELEASE_NODE", "boruta@node"},
      {"RELEASE_COOKIE", "cookie"},
      {"BORUTA_TEST_PID_STATUS", "0"},
      {"BORUTA_TEST_CAPTURE", context.capture},
      {"BORUTA_TEST_RPC_OUTPUT",
       "code: BAD_REQUEST\nmessage: invalid application\n__BORUTA_CLI_ERROR__"}
    ]

    assert {"code: BAD_REQUEST\nmessage: invalid application\n", 1} =
             System.cmd(context.wrapper, ["logs", "index"], env: env)
  end

  test "falls back to eval when RPC execution fails", context do
    env = [
      {"RELEASE_NODE", "boruta@node"},
      {"RELEASE_COOKIE", "cookie"},
      {"BORUTA_TEST_PID_STATUS", "0"},
      {"BORUTA_TEST_RPC_STATUS", "1"},
      {"BORUTA_TEST_CAPTURE", context.capture}
    ]

    assert {"", 0} = System.cmd(context.wrapper, ["role", "index"], env: env)

    assert ["eval", "BorutaAdmin.ReleaseCommand.main(System.argv())", "role", "index"] =
             context.capture |> File.read!() |> String.split("\n", trim: true)
  end

  test "formats remote command errors as YAML" do
    output =
      capture_io(fn ->
        assert :ok = BorutaAdmin.ReleaseCommand.remote([])
      end)

    assert output =~ ~s("code": "CLI_ERROR")
    assert output =~ ~s("message": "Usage: boruta-cli)
    assert output =~ ~s("errors":)
    refute output =~ "RuntimeError"
    assert String.ends_with?(output, "__BORUTA_CLI_ERROR__")
  end

  test "parses nested map parameters and merges common paths" do
    assert {
             %{
               "keya" => %{
                 "keyb" => "value",
                 "keyc" => %{"keyd" => "another-value"}
               }
             },
             ["attribute"]
           } =
             BorutaAdmin.ReleaseCommand.parse_arguments([
               "keya:keyb:value",
               "keya:keyc:keyd:another-value",
               "attribute"
             ])
  end

  test "keeps URL parameter values scalar at any nesting level" do
    assert {
             %{
               "redirect_uri" => "https://client.example/callback",
               "metadata" => %{
                 "issuer" => "did:example:123",
                 "logo_uri" => "https://client.example/logo.png"
               }
             },
             []
           } =
             BorutaAdmin.ReleaseCommand.parse_arguments([
               "redirect_uri:https://client.example/callback",
               "metadata:issuer:did:example:123",
               "metadata:logo_uri:https://client.example/logo.png"
             ])
  end

  test "does not interpret quoted string parameters" do
    assert {
             %{
               "schedule" => %{"time" => "12:30:00"},
               "time" => "12:30:00"
             },
             []
           } =
             BorutaAdmin.ReleaseCommand.parse_arguments([
               ~s(schedule:time:"12:30:00"),
               ~s(time:"12:30:00")
             ])
  end

  test "does not interpret ISO 8601 timestamps after shell quote removal" do
    assert {
             %{
               "end_at" => "2026-09-01T23:50:00+01:00",
               "start_at" => "2026-09-01T22:50:00Z"
             },
             []
           } =
             BorutaAdmin.ReleaseCommand.parse_arguments([
               "start_at:2026-09-01T22:50:00Z",
               "end_at:2026-09-01T23:50:00+01:00"
             ])
  end
end
