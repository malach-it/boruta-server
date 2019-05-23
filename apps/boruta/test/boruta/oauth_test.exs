defmodule Boruta.OauthTest do
  @behaviour Boruta.Oauth.Application

  use ExUnit.Case
  use Phoenix.ConnTest
  use Boruta.DataCase

  import Boruta.Factory

  alias Boruta.Oauth
  alias Authable.Model.Token

  describe "token request" do
    test "returns an error without params" do
      assert Oauth.token(%{}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Must provide body_params"
        }
      }}
    end

    test "returns an error with empty params" do
      assert Oauth.token(%{body_params: %{}}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request body validation failed. Required property grant_type is missing at #."
        }
      }}
    end

    test "returns an error with invalid grant_type" do
      assert Oauth.token(%{body_params: %{"grant_type" => "boom"}}, __MODULE__) == {:token_error, {
        :bad_request,
        %{
          error: "invalid_request",
          error_description: "Request body validation failed. #/grant_type do match required pattern /client_credentials|password/."
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
        :error,
        %{invalid_client: "Invalid client id or secret."},
        :unauthorized
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
      ) == {:token_error, {:error, %{invalid_client: "Invalid client id or secret."}, :unauthorized}}
    end

    test "returns an error if username/password are invalid", %{client: client} do
      %{req_headers: [{"authorization", authorization_header}]} = build_conn() |> using_basic_auth(client.id, client.secret)
      assert Oauth.token(
        %{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{"grant_type" => "password", "username" => "username", "password" => "password"}
        },
        __MODULE__
      ) == {:token_error, {:error, %{invalid_client: "Invalid client id or secret."}, :unauthorized}}
    end
  end

  @impl Boruta.Oauth.Application
  def token_error(_conn, error), do: {:token_error, error}

  @impl Boruta.Oauth.Application
  def token_success(_conn, token), do: {:token_success, token}

  defp using_basic_auth(conn, username, password) do
    header_content = "Basic " <> Base.encode64("#{username}:#{password}")
    conn |> put_req_header("authorization", header_content)
  end
end
