defmodule Boruta.OauthTest.ResourceOwnerPasswordCredentialsGrantTest do
  use ExUnit.Case
  # TODO remove conn dependency
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse

  describe "resource owner password credentials grant" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client)
      client_without_grant_type = insert(:client, supported_grant_types: [])
      client_with_scope = insert(:client,
        authorize_scope: true,
        authorized_scopes: [insert(:scope, name: "scope"), insert(:scope, name: "other")]
      )
      {:ok,
        client: client,
        client_with_scope: client_with_scope,
        client_without_grant_type: client_without_grant_type,
        resource_owner: resource_owner
      }
    end

    test "returns an error if Basic auth fails" do
      assert Oauth.token(
        %{
          req_headers: [{"authorization", "Basic boom"}],
          body_params: %{}
        },
        ApplicationMock
      ) == {:token_error, %Boruta.Oauth.Error{
        error: :invalid_request,
        error_description: "Given credentials are invalid.",
        status: :bad_request
      }}
    end

    test "returns an error if request is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password"}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. #/client_id do match required pattern /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/. Required properties username, password are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if client_id/secret are invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("6a2f41a3-c54c-fce8-32d2-0324e1c32e22", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => "username", "password" => "password"}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or client_secret.",
        status: :unauthorized
      }}
    end

    test "returns an error if username is invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => "username", "password" => "password"}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_resource_owner,
        error_description: "Invalid username or password.",
        status: :unauthorized
      }}
    end

    test "returns an error if password is invalid", %{client: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "boom"}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_resource_owner,
        error_description: "Invalid username or password.",
        status: :unauthorized
      }}
    end

    test "returns a token", %{client: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      case Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password"}
        },
        ApplicationMock
      ) do
        {:token_success,
          %TokenResponse{
            token_type: token_type,
            access_token: access_token,
            expires_in: expires_in,
            refresh_token: refresh_token
          }
        } ->
          assert token_type == "bearer"
          assert access_token
          assert expires_in
          assert refresh_token
        _ ->
          assert false
      end
    end

    test "returns a token if scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      %{name: given_scope} = List.first(client.authorized_scopes)
      case Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password", "scope" => given_scope}
        },
        ApplicationMock
      ) do
        {:token_success,
          %TokenResponse{
            token_type: token_type,
            access_token: access_token,
            expires_in: expires_in,
            refresh_token: refresh_token
          }
        } ->
          assert token_type == "bearer"
          assert access_token
          assert expires_in
          assert refresh_token
        _ ->
          assert false
      end
    end

    test "returns an error if scope is unknown or unauthorized by the client", %{client_with_scope: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      given_scope = "bad_scope"
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password", "scope" => given_scope}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are unknown or unauthorized.",
        status: :bad_request
      }}
    end

    test "returns an error if grant type is not allowed by the client", %{client_without_grant_type: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "password",
            "username" => resource_owner.email,
            "password" => "password",
            "scope" => ""
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :unsupported_grant_type,
        error_description: "Client do not support given grant type.",
        status: :bad_request
      }}
    end
  end

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
