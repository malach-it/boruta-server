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
