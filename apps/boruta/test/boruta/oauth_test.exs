defmodule Boruta.OauthTest do
  @behaviour Boruta.Oauth.Application

  use ExUnit.Case
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token

  describe "token request" do
    test "returns an error without params" do
      assert Oauth.token(%{}, __MODULE__) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Must provide body_params.",
        status: :bad_request
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.token(%{body_params: %{}}, __MODULE__) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request is not a valid OAuth request. Need a grant_type or a response_type param.",
        status: :bad_request
      }}
    end

    test "returns an error with invalid grant_type" do
      assert Oauth.token(%{body_params: %{"grant_type" => "boom"}}, __MODULE__) == {:token_error,  %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. #/grant_type do match required pattern /client_credentials|password|authorization_code/.",
        status: :bad_request
      }}
    end
  end

  describe "authorize request" do
    test "returns an error without params" do
      assert Oauth.authorize(%{}, __MODULE__) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Must provide query_params and assigns.",
        status: :bad_request
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.authorize(%{query_params: %{}, assigns: %{}}, __MODULE__) == {:authorize_error,
        %Error{
          error: :invalid_request,
          error_description: "Request is not a valid OAuth request. Need a grant_type or a response_type param.",
          status: :bad_request
        }
      }
    end

    test "returns an error with invalid response_type" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "boom"}, assigns: %{}}, __MODULE__) == {:authorize_error, %Error{
        error: :invalid_request,
        error_description: "Query params validation failed. #/response_type do match required pattern /token|code/.",
        status: :bad_request
      }}
    end
  end

  describe "client credentials grant" do
    setup do
      client = insert(:client)
      client_with_scope = insert(:client, authorize_scope: true, authorized_scopes: ["scope", "other"])
      {:ok, client: client, client_with_scope: client_with_scope}
    end

    test "returns an error if `grant_type` is 'client_credentials' and schema is invalid" do
      assert Oauth.token(%{body_params: %{"grant_type" => "client_credentials"}}, __MODULE__) == {:token_error, %Error{
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
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or client_secret.",
        status: :unauthorized
      }}
    end

    test "returns a token if client_id/scret are valid", %{client: client} do
      with {:token_success, %Token{client_id: client_id, value: value}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret
          }
        },
        __MODULE__
      ) do
        assert client_id == client.id
        assert value
      else
        _ ->
          assert false
      end
    end

    test "returns a token with scope", %{client: client} do
      given_scope = "hello world"
      with {:token_success, %Token{client_id: client_id, scope: scope, value: value}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        __MODULE__
      ) do
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns a token if scope is authorized", %{client_with_scope: client} do
      given_scope = List.first(client.authorized_scopes)
      with {:token_success, %Token{client_id: client_id, scope: scope, value: value}} <- Oauth.token(
        %{
          body_params: %{
            "grant_type" => "client_credentials",
            "client_id" => client.id,
            "client_secret" => client.secret,
            "scope" => given_scope
          }
        },
        __MODULE__
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
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are not authorized.",
        status: :bad_request
      }}
    end
  end

  describe "resource owner password credentials grant" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client)
      client_with_scope = insert(:client, authorize_scope: true, authorized_scopes: ["scope", "other"])
      {:ok, client: client, client_with_scope: client_with_scope, resource_owner: resource_owner}
    end

    test "returns an error if Basic auth fails" do
      assert Oauth.token(
        %{
          req_headers: [{"authorization", "boom"}],
          body_params: %{}
        },
        __MODULE__
      ) == {:token_error, %Boruta.Oauth.Error{
        error: :invalid_request,
        error_description: "`boom` is not a valid Basic authorization header.",
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
        __MODULE__
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
        __MODULE__
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
        __MODULE__
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
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_resource_owner,
        error_description: "Invalid username or password.",
        status: :unauthorized
      }}
    end

    test "returns a token if username/password are valid", %{client: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      with {
        :token_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value}
      } <- Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password"}
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
      else
        _ ->
          assert false
      end
    end

    test "returns a token with scope", %{client: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      given_scope = "hello world"
      with {
        :token_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value, scope: scope}
      } <- Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password", "scope" => given_scope}
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns a token if scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      given_scope = List.first(client.authorized_scopes)
      with {
        :token_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value, scope: scope}
      } <- Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password", "scope" => given_scope}
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns an error if scope is not authorized by the client", %{client_with_scope: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      given_scope = "bad_scope"
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "password", "scope" => given_scope}
        },
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are not authorized.",
        status: :bad_request
      }}
    end
  end

  describe "authorization code grant - authorize" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client, redirect_uri: "https://redirect.uri")
      client_with_scope = insert(:client, redirect_uri: "https://redirect.uri", authorize_scope: true, authorized_scopes: ["scope", "other"])
      {:ok, client: client, client_with_scope: client_with_scope, resource_owner: resource_owner}
    end

    test "returns an error if `response_type` is 'code' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "code"}, assigns: %{}}, __MODULE__) == {:authorize_error, %Error{
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
        },
        assigns: %{}
      }, __MODULE__) == {:authorize_error, %Error{
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
        },
        assigns: %{}
      }, __MODULE__) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :query,
        redirect_uri: "http://bad.redirect.uri"
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      assert Oauth.authorize(%{
        query_params: %{
          "response_type" => "code",
          "client_id" => client.id,
          "redirect_uri" => client.redirect_uri
        },
        assigns: %{}
      }, __MODULE__) == {:authorize_error, %Error{
        error: :invalid_resource_owner,
        error_description: "Resource owner is invalid.",
        status: :unauthorized,
        format: :query,
        redirect_uri: client.redirect_uri
      }}
    end

    test "returns a code if user is valid", %{client: client, resource_owner: resource_owner} do
      with {
        :authorize_success,
        %Boruta.Oauth.Token{type: "code", resource_owner_id: resource_owner_id, client_id: client_id, value: value}
      } <- Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri
          },
        assigns: %{current_user: resource_owner}
      }, __MODULE__) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
      else
        _ ->
          assert false
      end
    end

    test "returns a token with scope", %{client: client, resource_owner: resource_owner} do
      given_scope = "hello world"
      with {
        :authorize_success,
        %Boruta.Oauth.Token{
          type: "code",
          resource_owner_id: resource_owner_id,
          client_id: client_id,
          value: value,
          scope: scope
        }
      } <- Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" =>  given_scope
          },
        assigns: %{current_user: resource_owner}
      }, __MODULE__) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns a token if scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      given_scope = List.first(client.authorized_scopes)
      with {
        :authorize_success,
        %Boruta.Oauth.Token{
          type: "code",
          resource_owner_id: resource_owner_id,
          client_id: client_id,
          value: value,
          scope: scope
        }
      } <- Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" =>  given_scope
          },
        assigns: %{current_user: resource_owner}
      }, __MODULE__) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns an error if scope is not authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      given_scope = "bad_scope"
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" =>  given_scope
          },
        assigns: %{current_user: resource_owner}
      }, __MODULE__) == {:authorize_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are not authorized.",
        format: :query,
        redirect_uri: "https://redirect.uri",
        status: :bad_request
      }}
    end

    test "returns a code with state", %{client: client, resource_owner: resource_owner} do
      given_state = "state"
      with {
        :authorize_success,
        %Boruta.Oauth.Token{
          type: "code",
          resource_owner_id: resource_owner_id,
          client_id: client_id,
          value: value,
          state: state
        }
      } <- Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "state" => given_state
          },
        assigns: %{current_user: resource_owner}
      }, __MODULE__) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert state == given_state
      else
        _ ->
          assert false
      end
    end
  end

  describe "authorization code grant - token" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client)
      code = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: client.redirect_uri
      )
      expired_code = insert(
        :token,
        type: "code",
        client_id: client.id,
        resource_owner_id: resource_owner.id,
        redirect_uri: client.redirect_uri,
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
        redirect_uri: client.redirect_uri,
        scope: "hello world"
      )
      {:ok,
        client: client,
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
        __MODULE__
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
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized
      }}
    end

    test "returns an error if `code` is invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")

      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => "bad_code",
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_code,
        error_description: "Provided authorization code is incorrect.",
        status: :unauthorized
      }}
    end

    test "returns an error if `code` and request redirect_uri do not match", %{client: client, bad_redirect_uri_code: bad_redirect_uri_code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => bad_redirect_uri_code.value,
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_code,
        error_description: "Provided authorization code is incorrect.",
        status: :unauthorized
      }}
    end

    test "returns an error if `code` is expired", %{client: client, expired_code: expired_code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => expired_code.value,
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) == {:token_error, %Error{
        error: :invalid_code,
        error_description: "Token expired.",
        status: :unauthorized
      }}
    end

    test "returns a token if `code` is valid", %{client: client, code: code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      with {
        :token_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value}
      } <- Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => code.value,
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) do
        assert resource_owner_id == code.resource_owner_id
        assert client_id == client.id
        assert value
      else
        _ ->
          assert false
      end
    end

    test "returns a token with scope", %{client: client, code_with_scope: code} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      with {
        :token_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value, scope: scope}
      } <- Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{
            "grant_type" => "authorization_code",
            "client_id" => client.id,
            "code" => code.value,
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) do
        assert resource_owner_id == code.resource_owner_id
        assert client_id == client.id
        assert value
        assert scope == code.scope
      else
        _ ->
          assert false
      end
    end
  end

  describe "implicit grant" do
    setup do
      resource_owner = insert(:user)
      client = insert(:client, redirect_uri: "https://redirect.uri")
      client_with_scope = insert(:client, redirect_uri: "https://redirect.uri", authorize_scope: true, authorized_scopes: ["scope", "other"])
      {:ok, client: client, client_with_scope: client_with_scope, resource_owner: resource_owner}
    end

    test "returns an error if `response_type` is 'token' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "token"}, assigns: %{}}, __MODULE__) == {:authorize_error, %Error{
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
        __MODULE__
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
        __MODULE__
      ) == {:authorize_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or redirect_uri.",
        status: :unauthorized,
        format: :fragment,
        redirect_uri: "http://bad.redirect.uri"
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri
          },
          assigns: %{}
        },
        __MODULE__
      ) == {:authorize_error,  %Error{
        error: :invalid_resource_owner,
        error_description: "Resource owner is invalid.",
        status: :unauthorized,
        format: :fragment,
        redirect_uri: client.redirect_uri
      }}
    end

    test "returns a token if user is valid", %{client: client, resource_owner: resource_owner} do
      with {
        :authorize_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value}
      } <- Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
      else
        _ ->
          assert false
      end
    end

    test "returns a token with scope", %{client: client, resource_owner: resource_owner} do
      given_scope = "hello world"
      with {
        :authorize_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value, scope: scope}
      } <- Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" => given_scope
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns a token id scope is authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      given_scope = List.first(client.authorized_scopes)
      with {
        :authorize_success,
        %Boruta.Oauth.Token{resource_owner_id: resource_owner_id, client_id: client_id, value: value, scope: scope}
      } <- Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" => given_scope
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        __MODULE__
      ) do
        assert resource_owner_id == resource_owner.id
        assert client_id == client.id
        assert value
        assert scope == given_scope
      else
        _ ->
          assert false
      end
    end

    test "returns an error if scope is not authorized", %{client_with_scope: client, resource_owner: resource_owner} do
      given_scope = "bad_scope"
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri,
            "scope" => given_scope
          },
          assigns: %{
            current_user: resource_owner
          }
        },
        __MODULE__
      ) == {:authorize_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are not authorized.",
        format: :fragment,
        redirect_uri: "https://redirect.uri",
        status: :bad_request
      }}
    end
  end

  describe "introspect request" do
    setup do
      client = insert(:client)
      resource_owner = insert(:user)
      token = insert(:token, type: "access_token", client_id: client.id, scope: "scope", resource_owner_id: resource_owner.id)
      {:ok, client: client, token: token}
    end

    test "returns an error without params" do
      assert Oauth.introspect(%{}, __MODULE__) == {:introspect_error, %Error{
        error: :invalid_request,
        error_description: "Must provide body_params.",
        status: :bad_request
      }}
    end

    test "returns an error with invalid request" do
      assert Oauth.introspect(%{body_params: %{}}, __MODULE__) == {:introspect_error, %Error{
        error: :invalid_request,
        error_description: "Request validation failed. Required properties client_id, client_secret, token are missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error with invalid client_id/secret", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, "bad_secret")

      assert Oauth.introspect(%{
        body_params: %{"token" => "token"},
        req_headers: [{"authorization", authorization_header}]
      }, __MODULE__) == {:introspect_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or client_secret.",
        status: :unauthorized
      }}
    end

    test "returns an inactive token if token is inactive", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)

      assert Oauth.introspect(%{
        body_params: %{"token" => "token"},
        req_headers: [{"authorization", authorization_header}]
      }, __MODULE__) == {:introspect_error, %Boruta.Oauth.Error{
        error: :invalid_access_token,
        error_description: "Provided access token is incorrect.",
        format: nil,
        redirect_uri: nil,
        status: :unauthorized
      }}
    end

    test "returns a token introspected if token is active", %{client: client, token: token} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      token = Repo.preload(token, [:resource_owner, :client])

      with {:introspect_success, %Token{} = token} <- Oauth.introspect(%{
        body_params: %{"token" => token.value},
        req_headers: [{"authorization", authorization_header}]
      }, __MODULE__) do
        assert token == token
      end
    end
  end

  @impl Boruta.Oauth.Application
  def token_error(_conn, error), do: {:token_error, error}

  @impl Boruta.Oauth.Application
  def token_success(_conn, token), do: {:token_success, token}

  @impl Boruta.Oauth.Application
  def authorize_error(_conn, error), do: {:authorize_error, error}

  @impl Boruta.Oauth.Application
  def authorize_success(_conn, authorize), do: {:authorize_success, authorize}

  @impl Boruta.Oauth.Application
  def introspect_error(_conn, error), do: {:introspect_error, error}

  @impl Boruta.Oauth.Application
  def introspect_success(_conn, authorize), do: {:introspect_success, authorize}

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
