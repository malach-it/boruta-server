defmodule Boruta.OauthTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  alias Boruta.Oauth

  describe "token_request" do
    test "returns an error without params" do
      assert Oauth.token(%{}, __MODULE__) == {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Must provide query_params and body_params"
        }
      }
    end

    test "returns an error with empty params" do
      assert Oauth.token(%{query_params: %{}, body_params: %{}}, __MODULE__) == {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Query params validation failed. Required property grant_type is missing at #"
        }
      }
    end

    test "returns an error with invalid grant_type" do
      assert Oauth.token(%{query_params: %{"grant_type" => "boom"}, body_params: %{}}, __MODULE__) == {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Query params validation failed. #/grant_type do match required pattern /client_credentials/"
        }
      }
    end

    test "returns an error if `grant_type` is 'client_credentials' and schema is invalid" do
      assert Oauth.token(%{query_params: %{"grant_type" => "client_credentials"}, body_params: %{}}, __MODULE__) == {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Body params validation failed. Required properties client_secret, client_id are missing at #"
        }
      }
    end
  end

  def token_error(conn, error), do: IO.inspect error
end
