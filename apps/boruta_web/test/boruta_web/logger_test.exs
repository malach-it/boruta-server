defmodule BorutaWeb.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  describe "authorization_token_success_handler/4" do
    test "logs the authorization code" do
      log =
        capture_log([level: :info], fn ->
          BorutaWeb.Logger.authorization_token_success_handler(
            nil,
            %{},
            %{
              client_id: "client-id",
              sub: "user-id",
              access_token: "access-token",
              agent_token: nil,
              authorization_code: "authorization-code",
              token_type: "bearer",
              expires_in: 60,
              refresh_token: nil
            },
            nil
          )
        end)

      assert log =~ "authorization token - success"
      assert log =~ "authorization_code=authorization-code"
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
              code: "code-value",
              code_id: "code-id",
              response_type: "id_token",
              requested_scope: "openid",
              id_token: true,
              vp_token: false
            },
            nil
          )
        end)

      assert log =~ "authorization direct_post - success"
      assert log =~ "client_id=client-id"
      assert log =~ "code=code-value"
      assert log =~ ~s(response_type="id_token")
      assert log =~ "id_token=true"
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
