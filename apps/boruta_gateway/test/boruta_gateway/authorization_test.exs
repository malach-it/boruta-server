defmodule BorutaGateway.AuthorizationTest do
  use ExUnit.Case, async: false

  alias BorutaGateway.Authorization
  alias BorutaGateway.Upstreams.Upstream

  defmodule ResourceOwners do
    def get_by(username: "alice") do
      {:ok, %Boruta.Oauth.ResourceOwner{sub: "user-id", username: "alice"}}
    end

    def get_by(username: _username), do: {:error, "Invalid username or password."}

    def check_password(%Boruta.Oauth.ResourceOwner{username: "alice"}, "correct:password"),
      do: :ok

    def check_password(_resource_owner, _password),
      do: {:error, "Invalid username or password."}

    def authorized_scopes(%Boruta.Oauth.ResourceOwner{username: "alice"}) do
      [%Boruta.Oauth.Scope{name: "read"}, %{name: "write"}]
    end
  end

  setup do
    previous_adapter =
      Application.get_env(:boruta_gateway, :basic_authorization_resource_owners)

    Application.put_env(
      :boruta_gateway,
      :basic_authorization_resource_owners,
      ResourceOwners
    )

    on_exit(fn ->
      if previous_adapter do
        Application.put_env(
          :boruta_gateway,
          :basic_authorization_resource_owners,
          previous_adapter
        )
      else
        Application.delete_env(:boruta_gateway, :basic_authorization_resource_owners)
      end
    end)

    :ok
  end

  test "authorizes HTTP Basic credentials against the configured resource owners" do
    upstream = basic_upstream(%{"GET" => ["read"]})

    assert {:ok, :basic_authorized} =
             Authorization.authorize(
               request("alice", "correct:password"),
               "GET",
               upstream
             )
  end

  test "returns forbidden when the authenticated user lacks a required scope" do
    upstream = basic_upstream(%{"GET" => ["admin"]})

    assert {:forbidden, "text/plain", "forbidden"} =
             Authorization.authorize(
               request("alice", "correct:password"),
               "GET",
               upstream
             )
  end

  test "challenges malformed and invalid HTTP Basic credentials" do
    upstream = basic_upstream()

    assert {:unauthorized, "text/plain", "unauthorized",
            ~s(Basic realm="Boruta gateway", charset="UTF-8")} =
             Authorization.authorize(
               request("alice", "wrong"),
               "GET",
               upstream
             )

    assert {:unauthorized, "text/plain", "unauthorized",
            ~s(Basic realm="Boruta gateway", charset="UTF-8")} =
             Authorization.authorize(
               "GET / HTTP/1.1\r\nAuthorization: Basic invalid\r\n\r\n",
               "GET",
               upstream
             )
  end

  test "keeps OAuth bearer authorization as the default" do
    upstream = %Upstream{
      authorize: true,
      error_content_type: "text/plain",
      forbidden_response: "forbidden",
      unauthorized_response: "unauthorized"
    }

    assert {:unauthorized, "text/plain", "unauthorized", nil} =
             Authorization.authorize("GET / HTTP/1.1\r\n\r\n", "GET", upstream)
  end

  defp basic_upstream(required_scopes \\ %{}) do
    %Upstream{
      authorize: true,
      authorization_type: "http_basic",
      required_scopes: required_scopes,
      error_content_type: "text/plain",
      forbidden_response: "forbidden",
      unauthorized_response: "unauthorized"
    }
  end

  defp request(username, password) do
    credentials = Base.encode64("#{username}:#{password}")
    "GET / HTTP/1.1\r\nAuthorization: Basic #{credentials}\r\n\r\n"
  end
end
