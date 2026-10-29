defmodule BorutaGateway.AuthorizationTest do
  use ExUnit.Case, async: false
  use BorutaGateway.DataCase

  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.ClientStore
  alias BorutaGateway.Authorization
  alias BorutaGateway.BasicAccessTokens
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
      # A direct grant and a role grant can overlap.
      [%Boruta.Oauth.Scope{name: "read"}, %{name: "write"}, %{name: "read"}]
    end
  end

  setup do
    previous_public = ClientStore.get_public()
    {:ok, client} = Admin.create_client(%{access_token_ttl: 3600})
    public = Boruta.ClientsAdapter.get_client(client.id)
    {:ok, ^public} = ClientStore.put_public(public)

    previous_adapter =
      Application.get_env(:boruta_gateway, :basic_authorization_resource_owners)

    Application.put_env(
      :boruta_gateway,
      :basic_authorization_resource_owners,
      ResourceOwners
    )

    on_exit(fn ->
      case previous_public do
        {:ok, client} -> ClientStore.put_public(client)
        _ -> ClientStore.invalidate_public()
      end

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

    {:ok, public_client: public}
  end

  test "persists only upstream-required scopes after checking the user's grants", %{
    public_client: public
  } do
    upstream = basic_upstream(%{"GET" => ["read"]})

    assert {:ok, {:basic_authorized, token}} =
             Authorization.authorize(
               request("alice", "correct:password"),
               "GET",
               upstream
             )

    assert token.client.id == public.id
    assert token.scope == "read"
    assert token.sub == "user-id"
    persisted = BorutaAuth.Repo.get!(Boruta.Ecto.Token, token.id)
    assert persisted.value == token.value
    assert persisted.sub == "user-id"
    assert persisted.scope == "read"
    assert persisted.client_id == public.id
    assert token.expires_at == DateTime.to_unix(token.inserted_at) + public.access_token_ttl
    assert {:ok, ^token} = Boruta.Oauth.Authorization.AccessToken.authorize(value: token.value)
    assert {:ok, _} = Boruta.AccessTokensAdapter.revoke(token)
  end

  test "reuses the persisted token without extending its lifetime" do
    request = request("alice", "correct:password")
    upstream = basic_upstream(%{"GET" => ["read"]})
    assert {:ok, {:basic_authorized, first}} = Authorization.authorize(request, "GET", upstream)
    assert {:ok, {:basic_authorized, second}} = Authorization.authorize(request, "GET", upstream)
    assert first.value =~ ~r/^basic-[0-9A-F]{64}$/
    assert second.id == first.id
    assert second.value == first.value
    assert second.expires_at == first.expires_at

    query =
      Ecto.Query.from(token in Boruta.Ecto.Token, where: token.client_id == ^first.client.id)

    assert BorutaAuth.Repo.aggregate(query, :count) == 1
  end

  test "concurrent requests reuse an existing persisted token", %{public_client: public} do
    params = %{
      client: public,
      resource_owner: %Boruta.Oauth.ResourceOwner{sub: "concurrent-user"},
      sub: "concurrent-user",
      scope: "read"
    }

    assert {:ok, existing} = BasicAccessTokens.get_or_create(params, {"alice", "password"})

    tokens =
      1..8
      |> Task.async_stream(
        fn _ -> BasicAccessTokens.get_or_create(params, {"alice", "password"}) end,
        max_concurrency: 4
      )
      |> Enum.map(fn {:ok, {:ok, token}} -> token end)

    assert Enum.all?(tokens, &(&1.id == existing.id))
    query = Ecto.Query.from(token in Boruta.Ecto.Token, where: token.client_id == ^public.id)
    assert BorutaAuth.Repo.aggregate(query, :count) == 1
  end

  test "revoking a Basic token persists revocation and invalidates the cache" do
    assert {:ok, {:basic_authorized, token}} =
             Authorization.authorize(
               request("alice", "correct:password"),
               "GET",
               basic_upstream(%{"GET" => ["read"]})
             )

    assert {:ok, _} = Boruta.AccessTokensAdapter.revoke(token)
    assert {:error, "Not cached."} = Boruta.Ecto.TokenStore.get(value: token.value)
    assert BorutaAuth.Repo.get!(Boruta.Ecto.Token, token.id).revoked_at
    assert {:error, _} = Boruta.Oauth.Authorization.AccessToken.authorize(value: token.value)
  end

  test "uses method-specific scopes, wildcard fallback and empty scope configuration" do
    for {configuration, expected} <- [
          {%{}, ""},
          {%{"*" => ["write"]}, "write"},
          {%{"*" => ["write"], "GET" => ["read"]}, "read"},
          {%{"*" => ["write"], "GET" => []}, ""},
          {%{"GET" => ["read", "read"]}, "read"}
        ] do
      assert {:ok, {:basic_authorized, token}} =
               Authorization.authorize(
                 request("alice", "correct:password"),
                 "GET",
                 basic_upstream(configuration)
               )

      assert token.scope == expected
    end
  end

  test "denies a method without a configured rule or wildcard" do
    assert {:forbidden, _, _} =
             Authorization.authorize(
               request("alice", "correct:password"),
               "GET",
               basic_upstream(%{"POST" => ["write"]})
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

  test "Basic-protected upstreams continue to require Basic credentials" do
    upstream = basic_upstream()

    assert {:ok, {:basic_authorized, token}} =
             Authorization.authorize(request("alice", "correct:password"), "GET", upstream)

    assert {:unauthorized, _, _, _} =
             Authorization.authorize(
               "GET / HTTP/1.1\r\nAuthorization: Bearer #{token.value}\r\n\r\n",
               "GET",
               upstream
             )

    assert {:ok, _} = Boruta.AccessTokensAdapter.revoke(token)
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
      id: Ecto.UUID.generate(),
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
