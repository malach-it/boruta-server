defmodule Boruta.OauthTest.ImplicitGrantTest do
  use ExUnit.Case
  use Boruta.DataCase

  import Boruta.Factory
  import Mox

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Support.ResourceOwners
  alias Boruta.Support.User

  describe "implicit grant" do
    setup do
      resource_owner = %User{}
      client = insert(:client, redirect_uris: ["https://redirect.uri"])
      client_without_grant_type = insert(:client, supported_grant_types: [])
      client_with_scope = insert(:client,
        redirect_uris: ["https://redirect.uri"],
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
      ResourceOwners
      |> stub(:get_by, fn(_params) -> nil end)
      |> stub(:persisted?, fn(_params) -> false end)
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
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
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
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      |> stub(:authorized_scopes, fn (_resource_owner) -> [] end)
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
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      |> stub(:authorized_scopes, fn (_resource_owner) -> [] end)
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

    test "returns an error if grant type is not allowed by the client", %{client_without_grant_type: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      |> stub(:authorized_scopes, fn (_resource_owner) -> [] end)
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" => ""
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        ApplicationMock
      ) == {:authorize_error, %Error{
        error: :unsupported_grant_type,
        error_description: "Client do not support given grant type.",
        format: :fragment,
        redirect_uri: redirect_uri,
        status: :bad_request
      }}
    end
  end
end
