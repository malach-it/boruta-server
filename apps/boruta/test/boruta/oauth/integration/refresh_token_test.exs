defmodule Boruta.OauthTest.RefreshTokenTest do
  use ExUnit.Case
  # TODO remove conn dependency
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Boruta.Oauth.ApplicationMock
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse

  describe "refresh_token" do
    setup do
      client = insert(:client)
      expired_access_token = insert(
        :token,
        type: "access_token",
        refresh_token: "from_an_expired_token",
        client_id: client.id,
        redirect_uri: List.first(client.redirect_uris),
        expires_at: :os.system_time(:seconds) - 10
      )
      access_token = insert(
        :token,
        type: "access_token",
        refresh_token: "from_an_access_token",
        client_id: client.id,
        redirect_uri: List.first(client.redirect_uris),
        expires_at: :os.system_time(:seconds) + 10,
        scope: "scope"
      )
      {:ok, client: client, expired_access_token: expired_access_token, access_token: access_token}
    end

    test "returns an error if `grant_type` is 'refresh_token' and schema is invalid" do
      assert Oauth.token(%{body_params: %{"grant_type" => "refresh_token"}}, ApplicationMock) == {:token_error, %Error{
        error: :invalid_request,
        error_description: "Request body validation failed. Required property refresh_token is missing at #.",
        status: :bad_request
      }}
    end

    test "returns an error if client is invalid" do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth("6a2f41a3-c54c-fce8-32d2-0324e1c32e22", "test")
      assert Oauth.token(%{
        body_params: %{"grant_type" => "refresh_token", "refresh_token" => "refresh_token"},
        req_headers: [{"authorization", authorization_header}]
      }, ApplicationMock) == {:token_error, %Error{
        error: :invalid_client,
        error_description: "Invalid client_id or client_secret.",
        status: :unauthorized
      }}
    end

    test "returns an error if refresh_token is invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(%{
        body_params: %{"grant_type" => "refresh_token", "refresh_token" => "bad_refresh_token"},
        req_headers: [{"authorization", authorization_header}]
      }, ApplicationMock) == {:token_error, %Error{
        error: :invalid_refresh_token,
        error_description: "Provided refresh token is incorrect.",
        status: :bad_request
      }}
    end

    test "returns an error if access_token associated is expired", %{client: client, expired_access_token: token} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(%{
        body_params: %{"grant_type" => "refresh_token", "refresh_token" => token.refresh_token},
        req_headers: [{"authorization", authorization_header}]
      }, ApplicationMock) == {:token_error, %Error{
        error: :invalid_refresh_token,
        error_description: "Token expired.",
        status: :bad_request
      }}
    end

    test "returns an error if scope is unknown or unauthorized", %{client: client, access_token: token} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(%{
        body_params: %{"grant_type" => "refresh_token", "refresh_token" => token.refresh_token, "scope" => "bad_scope"},
        req_headers: [{"authorization", authorization_header}]
      }, ApplicationMock) == {:token_error, %Error{
        error: :invalid_scope,
        error_description: "Given scopes are unknown or unauthorized.",
        status: :bad_request
      }}
    end

    test "returns token", %{client: client, access_token: token} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      case Oauth.token(
        %{
          body_params: %{"grant_type" => "refresh_token", "refresh_token" => token.refresh_token, "scope" => "scope"},
          req_headers: [{"authorization", authorization_header}]
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
