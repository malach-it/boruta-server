defmodule Boruta.OauthTest.AuthorizationCodeGrantTest do
  use ExUnit.Case
  # TODO remove conn dependency
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory
  import Mox

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse
  alias Boruta.Support.ResourceOwners
  alias Boruta.Support.User

  describe "authorization code grant - authorize" do
    setup do
      resource_owner = %User{}
      client = insert(:client, redirect_uris: ["https://redirect.uri"])
      client_without_grant_type = insert(:client, supported_grant_types: [])
      client_with_scope = insert(:client,
        redirect_uris: ["https://redirect.uri"],
        authorize_scope: true,
        authorized_scopes: [
          insert(:scope, name: "public", public: true),
          insert(:scope, name: "private", public: false)
        ]
      )
      {:ok,
        client: client,
        client_with_scope: client_with_scope,
        client_without_grant_type: client_without_grant_type,
        resource_owner: resource_owner
      }
    end

    test "returns an error if `response_type` is 'code' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "code"}}, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Query params validation failed. Required properties client_id, redirect_uri are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if `client_id` is invalid" do
      assert Oauth.authorize(%{
        query_params: %{
          "response_type" => "code",
          "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
          "redirect_uri" => "http://redirect.uri"
        }
      }, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :query,
        redirect_uri: "http://redirect.uri"
      }}
    end

    test "returns an error if `redirect_uri` is invalid", %{client: client} do
      assert Oauth.authorize(%{
        query_params: %{
          "response_type" => "code",
          "client_id" => client.id,
          "redirect_uri" => "http://bad.redirect.uri"
        }
      }, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :query,
        redirect_uri: "http://bad.redirect.uri"
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> nil end)
      |> stub(:persisted?, fn(_params) -> false end)

      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(%{
        query_params: %{
          "response_type" => "code",
          "client_id" => client.id,
          "redirect_uri" => redirect_uri
        }
      }, nil, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_resource_owner,
        error_description: "Resource owner is invalid.",
        status: :unauthorized,
        format: :query,
        redirect_uri: redirect_uri
      }}
    end

    test "returns a code", %{client: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)

      redirect_uri = List.first(client.redirect_uris)
      case  Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri
          }
      }, resource_owner, ApplicationMock) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in
          }
        } ->
          assert type == "code"
          assert value
          assert expires_in
        _ ->
          assert false
      end
    end

    test "returns a code with public scope", %{client: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      given_scope = "public"
      redirect_uri = List.first(client.redirect_uris)

      case  Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" =>  given_scope
          },
      }, resource_owner, ApplicationMock) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in
          }
        } ->
          assert type == "code"
          assert value
          assert expires_in
        _ ->
          assert false
      end
    end

    test "returns an error with private scope", %{client: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      given_scope = "private"
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(%{
        query_params: %{
          "response_type" => "code",
          "client_id" => client.id,
          "redirect_uri" => redirect_uri,
          "scope" =>  given_scope
        }
      }, resource_owner, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are unknown or unauthorized.",
        status: :bad_request,
        format: :query,
        redirect_uri: redirect_uri
      }}
    end

    test "returns a token if scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      %{name: given_scope} = List.first(client.authorized_scopes)
      redirect_uri = List.first(client.redirect_uris)

      case Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" =>  given_scope
          }
      }, resource_owner, ApplicationMock) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in
          }
        } ->
          assert type == "code"
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
      given_scope = "bad_scope"
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" =>  given_scope
          }
      }, resource_owner, ApplicationMock) == {:authorize_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are unknown or unauthorized.",
        format: :query,
        redirect_uri: "https://redirect.uri",
        status: :bad_request
      }}
    end

    test "returns an error if grant type is not allowed by client", %{client_without_grant_type: client, resource_owner: resource_owner} do
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "scope" =>  ""
          }
      }, resource_owner, ApplicationMock) == {:authorize_error, %Error{
        error: :unsupported_grant_type,
        error_description: "Client do not support given grant type.",
        format: :query,
        redirect_uri: redirect_uri,
        status: :bad_request
      }}
    end

    test "returns a code with state", %{client: client, resource_owner: resource_owner} do
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      given_state = "state"
      redirect_uri = List.first(client.redirect_uris)
      case  Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => redirect_uri,
            "state" => given_state
          }
      }, resource_owner, ApplicationMock) do
        {:authorize_success,
          %AuthorizeResponse{
            type: type,
            value: value,
            expires_in: expires_in,
            state: state
          }
        } ->
          assert type == "code"
          assert value
          assert expires_in
          assert state == given_state
        _ ->
          assert false
      end
    end
  end

  describe "authorization code grant - token" do
    setup do
      resource_owner = %User{}
      client = insert(:client)
      client_without_grant_type = insert(:client, supported_grant_types: [])
      code = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: List.first(client.redirect_uris)
     )
      expired_code = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: List.first(client.redirect_uris),
        expires_at: :os.system_time(:seconds) - 10
      )
      bad_redirect_uri_code = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: "http://bad.redirect.uri"
      )
      code_with_scope = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: List.first(client.redirect_uris),
        scope: "hello world"
      )
      {:ok,
        client: client,
        client_without_grant_type: client_without_grant_type,
        resource_owner: resource_owner,
        code: code,
        bad_redirect_uri_code: bad_redirect_uri_code,
        expired_code: expired_code,
        code_with_scope: code_with_scope
      }
    end

    test "returns an error if request is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "authorization_code"}
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. #/client_id do match required pattern /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/. Required properties code, redirect_uri are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if `client_id` is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")

      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            "code" => "bad_code",
            "redirect_uri" => "http://redirect.uri"
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized
      }}
    end

    test "returns an error if `code` is invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      redirect_uri = List.first(client.redirect_uris)

      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => "bad_code",
            "redirect_uri" => redirect_uri
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_code,
        error_description: "Provided authorization code is incorrect.",
        status: :bad_request
      }}
    end

    test "returns an error if `code` and request redirect_uri do not match", %{client: client, bad_redirect_uri_code: bad_redirect_uri_code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => bad_redirect_uri_code.value,
            "redirect_uri" => redirect_uri
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :invalid_code,
        error_description: "Provided authorization code is incorrect.",
        status: :bad_request
      }}
    end

    test "returns an error if grant type is not allowed by client", %{client_without_grant_type: client, code: code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      redirect_uri = List.first(client.redirect_uris)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => code.value,
            "redirect_uri" => redirect_uri
          }
        },
        ApplicationMock
      ) == {:token_error, %Error{
        error: :unsupported_grant_type,
        error_description: "Client do not support given grant type.",
        status: :bad_request
      }}
    end

    test "returns a token", %{client: client, code: code, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      redirect_uri = List.first(client.redirect_uris)

      case Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => code.value,
            "redirect_uri" => redirect_uri
          }
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

    test "returns a token with scope", %{client: client, code_with_scope: code, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      ResourceOwners
      |> stub(:get_by, fn(_params) -> resource_owner end)
      |> stub(:persisted?, fn(_params) -> true end)
      redirect_uri = List.first(client.redirect_uris)
      case Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => code.value,
            "redirect_uri" => redirect_uri
          }
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
  end

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
