defmodule Boruta.OauthTest do
  @behaviour Boruta.Oauth.Application

  use ExUnit.Case
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.Token

  describe "token request" do
    test "returns an error without params" do
      assert Oauth.token(%{}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Must provide body_params."
        }
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.token(%{body_params: %{}}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request is not a valid OAuth request. Need a grant_type or a response_type param."
        }
      }}
    end

    test "returns an error with invalid grant_type" do
      assert Oauth.token(%{body_params: %{"grant_type" => "boom"}}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request body validation failed. #/grant_type do match required pattern /client_credentials|password|authorization_code/."
        }
      }}
    end
  end

  describe "authorize request" do
    test "returns an error without params" do
      assert Oauth.authorize(%{}, __MODULE__) == {:authorize_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request is not a valid OAuth request. Need a grant_type or a response_type param."
        }
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.authorize(%{query_params: %{}}, __MODULE__) == {:authorize_error,
        {:bad_request, %{
          error: "invalid_request", error_description: "Request is not a valid OAuth request. Need a grant_type or a response_type param."
        }}
      }
    end

    test "returns an error with invalid response_type" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "boom"}}, __MODULE__) == {:authorize_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Query params validation failed. #/response_type do match required pattern /token|code/."
        }
      }}
    end
  end

  describe "clients credentials grant" do
    setup do
      user = insert(:user)
      client = insert(:client, user_id: user.id)
      {:ok, client: client}
    end

    test "returns an error if `grant_type` is 'client_credentials' and schema is invalid" do
      assert Oauth.token(%{body_params: %{"grant_type" => "client_credentials"}}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request body validation failed. Required properties client_id, client_secret are missing at #."
        }
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
      ) == {:token_error, {
        :unauthorized, %{
          error: "invalid_client",
          error_description: "Invalid client_id or client_secret."
        }
      }}
    end

    test "returns a token if client_id/scret are valid", %{client: client} do
      with {:token_success, %Token{} = token} <- Oauth.token(
        %{body_params: %{"grant_type" => "client_credentials", "client_id" => client.id, "client_secret" => client.secret}},
        __MODULE__
      ) do
        assert token
      else
        error ->
          IO.inspect error
          assert false
      end
    end
  end

  describe "resource owner password credentials grant" do
    setup do
      resource_owner = insert(:user)
      user = insert(:user)
      client = insert(:client, user_id: user.id)
      {:ok, client: client, resource_owner: resource_owner}
    end

    test "returns an error if Basic auth fails" do
      assert Oauth.token(
        %{
          req_headers: [{"authorization", "boom"}],
          body_params: %{}
        },
        __MODULE__
      ) == {:token_error, {:bad_request, %{error: "invalid_request", error_description: "`boom` is not a valid Basic authorization header"}}}
    end

    test "returns an error if request is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password"}
        },
        __MODULE__
      ) == {:token_error, {:bad_request, %{error: "invalid_request", error_description: "Request body validation failed. #/client_id do match required pattern /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/. Required properties username, password are missing at #."}}}
    end

    test "returns an error if client_id/secret are invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("6a2f41a3-c54c-fce8-32d2-0324e1c32e22", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => "username", "password" => "password"}
        },
        __MODULE__
      ) == {:token_error, {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or client_secret."}}}
    end

    test "returns an error if username is invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => "username", "password" => "password"}
        },
        __MODULE__
      ) == {:token_error, {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}}
    end

    test "returns an error if password is invalid", %{client: client, resource_owner: resource_owner} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => resource_owner.email, "password" => "boom"}
        },
        __MODULE__
      ) == {:token_error, {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}}
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
  end

  describe "authorization code grant - authorize" do
    setup do
      resource_owner = insert(:user)
      user = insert(:user)
      client = insert(:client, user_id: user.id, redirect_uri: "https://redirect.uri")
      {:ok, client: client, resource_owner: resource_owner}
    end

    test "returns an error if `response_type` is 'code' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "code"}}, __MODULE__) == {:authorize_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Query params validation failed. Required properties client_id, redirect_uri are missing at #."
        }
      }}
    end

    test "returns an error if `client_id` is invalid" do
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            "redirect_uri" => "http://redirect.uri"
          }
      }, __MODULE__) == {:authorize_error, {
        :unauthorized,
        %{
          error: "invalid_client",
          error_description: "Invalid client_id or redirect_uri.",
          format: :query,
          redirect_uri: "http://redirect.uri"
        }
      }}
    end

    test "returns an error if `redirect_uri` is invalid", %{client: client} do
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => "http://bad.redirect.uri"
          }
      }, __MODULE__) == {:authorize_error, {
        :unauthorized,
        %{
          error: "invalid_client",
          error_description: "Invalid client_id or redirect_uri.",
          format: :query,
          redirect_uri: "http://bad.redirect.uri"
        }
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      assert Oauth.authorize(%{
          query_params: %{
            "response_type" => "code",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri
          }
      }, __MODULE__) == {:authorize_error, {
        :unauthorized,
        %{
          error: "invalid_resource_owner",
          error_description: "Resource owner is invalid.",
          format: :query,
          redirect_uri: client.redirect_uri
        }
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
  end

  describe "authorization code grant - token" do
    setup do
      resource_owner = insert(:user)
      user = insert(:user)
      client = insert(:client, user_id: user.id)
      code = insert(:token, type: "code", client_id: client.id, resource_owner_id: resource_owner.id)
      {:ok, client: client, resource_owner: resource_owner, code: code}
    end

    test "returns an error if request is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("test", "test")
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "authorization_code"}
        },
        __MODULE__
      ) == {:token_error, {
        :bad_request, %{
          error: "invalid_request",
          error_description: "Request body validation failed. #/client_id do match required pattern /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/. Required properties code, redirect_uri are missing at #."
        }
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
      ) == {:token_error, {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or redirect_uri."}}}
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
      ) == {:token_error, {:unauthorized, %{error: "invalid_code", error_description: "Provided authorization code is incorrect."}}}
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
  end

  describe "implicit grant" do
    setup do
      resource_owner = insert(:user)
      user = insert(:user)
      client = insert(:client, user_id: user.id, redirect_uri: "https://redirect.uri")
      {:ok, client: client, resource_owner: resource_owner}
    end

    test "returns an error if `response_type` is 'token' and schema is invalid" do
      assert Oauth.authorize(%{query_params: %{"response_type" => "token"}}, __MODULE__) == {:authorize_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Query params validation failed. Required properties client_id, redirect_uri are missing at #."
        }
      }}
    end

    test "returns an error if client_id is invalid" do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
            "redirect_uri" => "http://redirect.uri"
          }
        },
        __MODULE__
      ) == {:authorize_error, {
        :unauthorized, %{
          error: "invalid_client",
          error_description: "Invalid client_id or redirect_uri.",
          format: :fragment,
          redirect_uri: "http://redirect.uri"
        }
      }}
    end

    test "returns an error if redirect_uri is invalid", %{client: client} do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => "http://bad.redirect.uri"
          }
        },
        __MODULE__
      ) == {:authorize_error, {
        :unauthorized, %{
          error: "invalid_client",
          error_description: "Invalid client_id or redirect_uri.",
          format: :fragment,
          redirect_uri: "http://bad.redirect.uri"
        }
      }}
    end

    test "returns an error if user is invalid", %{client: client} do
      assert Oauth.authorize(
        %{
          query_params: %{
            "response_type" => "token",
            "client_id" => client.id,
            "redirect_uri" => client.redirect_uri
          }
        },
        __MODULE__
      ) == {:authorize_error, {
        :unauthorized, %{
          error: "invalid_resource_owner",
          error_description: "Resource owner is invalid.",
          format: :fragment,
          redirect_uri: client.redirect_uri
        }
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
        error ->
          IO.inspect error
          assert false
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

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
