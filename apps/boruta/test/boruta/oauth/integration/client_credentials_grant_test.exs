defmodule Boruta.OauthTest.ClientCredentialsGrantTest do
  use ExUnit.Case
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token

  describe "client credentials grant" do
    setup do
      client = insert(:client)
      client_with_scope = insert(:client,
        authorize_scope: true,
        authorized_scopes: [insert(:scope, name: "public", public: true), insert(:scope, name: "private", public: false)]
      )
      {:ok, client: client, client_with_scope: client_with_scope}
    end

    test "returns an error if `grant_type` is 'client_credentials' and schema is invalid" do
      assert Oauth.token(%{body_params: %{"grant_type" => "client_credentials"}}, ApplicationMock) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. Required properties client_id, client_secret are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if client_id/scret are invalid" do
      assert Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            "client_secret" => "client_secret"
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or client_secret.",
        status: :unauthorized
      }}
    end

    test "returns a token if client_id/scret are valid", %{client: client} do
      with {:token_success, %Token{client_id: client_id, value: value, refresh_token: refresh_token}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret
          }
        },
        ApplicationMock
      ) do
        assert client_id == client.id
        assert value
        assert refresh_token
      else
        _ ->
          assert false
      end
    end

    test "returns a token with public scope", %{client: client} do
      given_scope = "public"
      with {:token_success, %Token{client_id: client_id, scope: scope, value: value}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        ApplicationMock
      ) do
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns an error with private scope", %{client: client} do
      given_scope = "private"
      assert Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        ApplicationMock
      ) == {:token_error,
        %Boruta.Oauth.Error{
          error: :invalid_scope,
          error_description: "Given scopes are not authorized.",
          format: nil,
          redirect_uri: nil,
          status: :bad_request
        }
      }
    end

    test "returns a token if scope is authorized", %{client_with_scope: client} do
      %Scope{name: given_scope} = List.first(client.authorized_scopes)
      with {:token_success, %Token{client_id: client_id, scope: scope, value: value}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        ApplicationMock
      ) do
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns an error if scopes are not authorized", %{client_with_scope: client} do
      given_scope = "bad_scope"
      assert Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are not authorized.",
        status: :bad_request
      }}
    end
  end
end
