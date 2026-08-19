defmodule BorutaAuth.LogSanitizerTest do
  use ExUnit.Case, async: true

  alias BorutaAuth.LogSanitizer

  test "redacts reset password and confirmation tokens from paths" do
    assert LogSanitizer.redact_sensitive_path_tokens(
             "/accounts/users/reset_password/reset-secret"
           ) == "/accounts/users/reset_password/:token"

    assert LogSanitizer.redact_sensitive_path_tokens(
             "/users/confirm/confirmation-secret?request=context"
           ) == "/users/confirm/:token?request=context"
  end

  test "does not alter token-free paths" do
    path = "/accounts/users/reset_password"

    assert LogSanitizer.redact_sensitive_path_tokens(path) == path
  end
end
