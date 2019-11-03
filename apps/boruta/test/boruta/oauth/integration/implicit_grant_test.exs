defmodule Boruta.OauthTest.ImplicitGrantTest do
  use ExUnit.Case
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Clients
  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error

  describe "implicit grant" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client, redirect_uris: ["https://redirect.uri"])
      client_with_scope = insert(:client,
        redirect_uris: ["https://redirect.uri"],
        authorize_scope: true,
        authorized_scopes: [insert(:scope, name: "scope"), insert(:scope, name: "other")]
      )
      {:ok,
        client: Clients.to_oauth_schema(client),
        client_with_scope: Clients.to_oauth_schema(client_with_scope),
        resource_owner: resource_owner
      }
    end

    test "returns an error if `response_type` is 'token' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "token"}, assigns: %{}}, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Query params validation failed. Required properties client_id, redirect_uri are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if client_id is invalid" do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            "redirect_uri" => "http://redirect.uri"
          },
          assigns: %{}
        },
        ApplicationMock
      ) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :fragment,
        redirect_uri: "http://redirect.uri"
      }}
    end

    test "returns an error if redirect_uri is invalid", %{client: client} do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => "http://bad.redirect.uri"
          },
          assigns: %{}
        },
        ApplicationMock
      ) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :fragment,
        redirect_uri: "http://bad.redirect.uri"
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri
          },
          assigns: %{}
        },
        ApplicationMock
      ) == {:authorize_error,  %Error{
        error: :invalid_resource_owner,
        error_description: "Resource owner is invalid.",
        status: :unauthorized,
        format: :fragment,
        redirect_uri: redirect_uri
      }}
    end

    test "returns a token", %{client: client, resource_owner: resource_owner} do
      redirect_uri = List.first(client.redirect_uris)
      case Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        ApplicationMock
      ) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in
          }
        } ->
          assert type == "access_token"
          assert value
          assert expires_in
        _ ->
          assert false
      end
    end

    test "returns a token if scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      %{name: given_scope} = List.first(client.authorized_scopes)
      redirect_uri = List.first(client.redirect_uris)
      case  Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" => given_scope
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        ApplicationMock
      ) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in
          }
        } ->
          assert type == "access_token"
          assert value
          assert expires_in
        _ ->
          assert false
      end
    end

    test "returns an error if scope is unknown or unauthorized", %{client_with_scope: client, resource_owner: resource_owner} do
      given_scope = "bad_scope"
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" => given_scope
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        ApplicationMock
      ) == {:authorize_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are unknown or unauthorized.",
        format: :fragment,
        redirect_uri: "https://redirect.uri",
        status: :bad_request
      }}
    end
  end
end
