defmodule Boruta.OauthTest.CommonGrantTest do
  use ExUnit.Case

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.Error

  describe "token request" do
    test "returns an error without params" do
      assert Oauth.token(%{}, ApplicationMock) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Must provide body_params.",
        status: :bad_request
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.token(%{body_params: %{}}, ApplicationMock) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request is not a valid OAuth request. Need a grant_type param.",
        status: :bad_request
      }}
    end

    test "returns an error with invalid grant_type" do
      assert Oauth.token(%{body_params: %{"grant_type" => "boom"}}, ApplicationMock) == {:token_error,  %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. #/grant_type do match required pattern /^(client_credentials|password|authorization_code|refresh_token)$/.",
        status: :bad_request
      }}
    end

    @tag :skip
    test "with basic authorization header" do
    end
  end

  describe "authorize request" do
    test "returns an error without params" do
      assert Oauth.authorize(%{}, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Must provide query_params.",
        status: :bad_request
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.authorize(%{query_params: %{}}, nil, ApplicationMock) == {:authorize_error,
        %Error{
          error: :invalid_request,
          error_description: "Request is not a valid OAuth request. Need a response_type param.",
          status: :bad_request
        }
      }
    end

    test "returns an error with invalid response_type" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "boom"}}, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Query params validation failed. #/response_type do match required pattern /^(token|code)$/.",
        status: :bad_request
      }}
    end

    @tag :skip
    test "with basic authorization header" do
    end
  end
end
