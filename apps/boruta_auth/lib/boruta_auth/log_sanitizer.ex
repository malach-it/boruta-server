defmodule BorutaAuth.LogSanitizer do
  @moduledoc false

  @redacted_token ":token"
  @sensitive_path_regex ~r{(/users/(?:confirm|reset_password)/)[^/?\s]+}

  @spec redact_sensitive_path_tokens(String.t()) :: String.t()
  def redact_sensitive_path_tokens(value) when is_binary(value) do
    Regex.replace(@sensitive_path_regex, value, "\\1#{@redacted_token}")
  end
end
