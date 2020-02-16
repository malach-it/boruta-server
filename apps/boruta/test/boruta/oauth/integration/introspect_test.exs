defmodule Boruta.OauthTest.IntrospectTest do
  use ExUnit.Case
  # TODO remove conn dependency
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse

  describe "introspect request" do
    setup do
      client = insert(:client)
      resource_owner = insert(:user)
      token = insert(
        :token,
        type: "access_token",
        client: client,
        scope: "scope",
        resource_owner: resource_owner
      )
      {:ok,
        client: client,
        token: token
      }
    end

    test "returns an error without params" do
      assert Oauth.introspect(%{}, ApplicationMock) == {:introspect_error, %Error{
        error: :invalid_request,
        error_description: "Must provide body_params.",
        status: :bad_request
      }}
    end

    test "returns an error with invalid request" do
      assert Oauth.introspect(%{body_params: %{}}, ApplicationMock) == {:introspect_error, %Error{
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
      }, ApplicationMock) == {:introspect_error, %Error{
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
      }, ApplicationMock) == {:introspect_success,
        %IntrospectResponse{
          active: false,
          client_id: nil,
          exp: nil,
          iat: nil,
          iss: "boruta",
          scope: nil,
          sub: nil,
          username: nil
        }
      }
    end

    test "returns a token introspected if token is active", %{client: client, token: token} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      case Oauth.introspect(%{
        body_params: %{"token" => token.value},
        req_headers: [{"authorization", authorization_header}]
      }, ApplicationMock) do
        {:introspect_success, %IntrospectResponse{
          active: active,
          client_id: client_id,
          exp: exp,
          iat: iat,
          iss: iss,
          scope: scope,
          sub: sub,
          username: username
        }} ->
          assert active
          assert client_id
          assert exp
          assert iat
          assert iss
          assert scope
          assert sub
          assert username
        _ -> assert false
      end
    end
  end

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
