defmodule BorutaWeb.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  describe "authorization_token_success_handler/4" do
    test "does not log bearer credentials" do
      log =
        capture_log([level: :info], fn ->
          BorutaWeb.Logger.authorization_token_success_handler(
            nil,
            %{},
            %{
              client_id: "client-id",
              sub: "user-id",
              access_token: "access-token",
              agent_token: "agent-token",
              authorization_code: "authorization-code",
              token_type: "bearer",
              expires_in: 60,
              refresh_token: "refresh-token"
            },
            nil
          )
        end)

      assert log =~ "authorization token - success"
      refute log =~ "access-token"
      refute log =~ "agent-token"
      refute log =~ "refresh-token"
      refute log =~ "authorization-code"
    end
  end

  describe "authorization_direct_post_success_handler/4" do
    test "logs direct post success" do
      log =
        capture_log([level: :info], fn ->
          BorutaWeb.Logger.authorization_direct_post_success_handler(
            nil,
            %{},
            %{
              client_id: "client-id",
              sub: "user-id",
              code_id: "code-id",
              response_type: "id_token",
              requested_scope: "openid",
              id_token: "id-token",
              vp_token: "vp-token"
            },
            nil
          )
        end)

      assert log =~ "authorization direct_post - success"
      assert log =~ "client_id=client-id"
      assert log =~ ~s(response_type="id_token")
      refute log =~ "id-token"
      refute log =~ "vp-token"
    end
  end

  describe "authorization_direct_post_failure_handler/4" do
    test "logs direct post failure" do
      log =
        capture_log([level: :info], fn ->
          BorutaWeb.Logger.authorization_direct_post_failure_handler(
            nil,
            %{},
            %{
              code_id: "code-id",
              status: :unauthorized,
              error: :invalid_request,
              error_description: "Invalid direct post request."
            },
            nil
          )
        end)

      assert log =~ "authorization direct_post - failure"
      assert log =~ "code_id=code-id"
      assert log =~ "status=unauthorized"
      assert log =~ "error=invalid_request"
      assert log =~ ~s(error_description="Invalid direct post request.")
    end
  end
end
