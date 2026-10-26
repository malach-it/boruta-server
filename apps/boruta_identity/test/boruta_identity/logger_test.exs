defmodule BorutaIdentity.LoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import Plug.Test

  alias BorutaIdentity.Logger, as: IdentityLogger

  test "request logs redact reset password and confirmation tokens" do
    log =
      capture_log(fn ->
        log_request("/accounts/users/reset_password/reset-secret")
        log_request("/accounts/users/confirm/confirmation-secret")
      end)

    refute log =~ "reset-secret"
    refute log =~ "confirmation-secret"
    assert log =~ "/accounts/users/reset_password/:token"
    assert log =~ "/accounts/users/confirm/:token"
  end

  test "MFA business logs include the outcome and identifiers without authentication material" do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)

    for action <- [:registration, :authentication],
        factor <- [:totp, :webauthn],
        result <- [:success, :failure] do
      log =
        capture_log([level: :info], fn ->
          IdentityLogger.mfa_handler(
            [action, factor, result],
            %{},
            %{client_id: "client-1", sub: "user-1", backend_id: "backend-1"},
            :ok
          )
        end)

      assert log =~ "boruta_identity #{action} #{factor} - #{result}"
      assert log =~ "client_id=client-1 sub=user-1 backend_id=backend-1"
      refute log =~ "secret="
      refute log =~ "code="
      refute log =~ "challenge="
    end
  end

  defp log_request(path) do
    conn = conn(:get, path) |> Map.merge(%{status: 200, state: :sent})

    IdentityLogger.boruta_identity_request_handler(
      [:boruta_identity, :endpoint, :stop],
      %{duration: 1},
      %{conn: conn, options: [log: :warning]},
      :ok
    )
  end
end
