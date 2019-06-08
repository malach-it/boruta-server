defmodule Boruta.BasicAuthTest do
  use ExUnit.Case

  doctest Boruta.BasicAuth

  alias Boruta.BasicAuth

  describe "#decode" do
    test "returns an error if bad authorization header is given" do
      bad_authorization_header = "bad authorization header"

      assert BasicAuth.decode(bad_authorization_header) == {:error, "`bad authorization header` is not a valid Basic authorization header."}
    end

    test "returns an error if credentials are not in base64" do
      bad_credentials = "Basic bad"

      assert BasicAuth.decode(bad_credentials) == {:error, "Given credentials are invalid."}
    end

    test "returns username/password if credentials valid" do
      bad_credentials = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="

      assert BasicAuth.decode(bad_credentials) == {:ok, ["username", "password"]}
    end
  end
end
