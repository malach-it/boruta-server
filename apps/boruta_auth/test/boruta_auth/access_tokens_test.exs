defmodule BorutaAuth.AccessTokensTest do
  use ExUnit.Case, async: false

  alias Boruta.Oauth.{Client, ResourceOwner}
  alias BorutaAuth.AccessTokens

  defp params do
    %{
      client: %Client{id: Ecto.UUID.generate(), access_token_ttl: 3600},
      resource_owner: %ResourceOwner{sub: Ecto.UUID.generate(), username: "alice"},
      scope: "read write"
    }
  end

  test "creates, resolves and revokes a cache-only token without SQL" do
    handler = {__MODULE__, make_ref()}
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        BorutaAuth.Repo.config()[:telemetry_prefix] ++ [:query],
        fn _, _, _, _ -> send(parent, :sql_query) end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    params = params()
    assert {:ok, token} = AccessTokens.create_cached(params)
    assert token.client.id == params.client.id
    assert token.sub == params.resource_owner.sub
    assert token.scope == "read write"

    assert token.expires_at ==
             DateTime.to_unix(token.inserted_at) + params.client.access_token_ttl

    assert token.refresh_token == nil
    assert Boruta.AccessTokensAdapter.get_by(value: token.value) == token
    assert Boruta.AccessTokensAdapter.get_by(refresh_token: token.value) == nil
    assert {:ok, ^token} = Boruta.Oauth.Authorization.AccessToken.authorize(value: token.value)
    assert {:ok, _} = Boruta.AccessTokensAdapter.revoke(token)
    assert Boruta.AccessTokensAdapter.get_by(value: token.value) == nil
    refute_receive :sql_query
  end

  test "expired cache-only token cannot fall back to the database" do
    assert {:ok, token} =
             AccessTokens.create_cached(
               put_in(params(), [:client, Access.key(:access_token_ttl)], 1)
             )

    Process.sleep(1_100)
    assert AccessTokens.get_by(value: token.value) == nil
    assert {:error, _} = Boruta.Oauth.Authorization.AccessToken.authorize(value: token.value)
  end

  test "reuses a credential-derived token without extending its expiration" do
    params = params()
    assert {:ok, token} = AccessTokens.create_cached(params, {"alice", "password"})
    Process.sleep(1_100)
    assert {:ok, ^token} = AccessTokens.create_cached(params, {"alice", "password"})
    assert {:ok, other} = AccessTokens.create_cached(params, {"alice", "different"})
    refute other.value == token.value

    assert {:ok, scoped} =
             AccessTokens.create_cached(%{params | scope: "read"}, {"alice", "password"})

    refute scoped.value == token.value
  end

  test "concurrent requests resolve to the same cached token" do
    params = params()

    tokens =
      1..10
      |> Task.async_stream(fn _ -> AccessTokens.create_cached(params, {"alice", "password"}) end)
      |> Enum.map(fn {:ok, {:ok, token}} -> token end)

    assert length(Enum.uniq(tokens)) == 1
  end

  test "rejects a nonpositive client lifetime" do
    assert_raise FunctionClauseError, fn ->
      AccessTokens.create_cached(put_in(params(), [:client, Access.key(:access_token_ttl)], 0))
    end
  end
end
