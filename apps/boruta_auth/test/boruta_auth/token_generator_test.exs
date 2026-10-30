defmodule BorutaAuth.TokenGeneratorTest do
  use ExUnit.Case, async: true

  alias Boruta.Oauth.{Client, ResourceOwner, Token}
  alias BorutaAuth.TokenGenerator

  setup do
    params = %{
      client: %Client{id: "client-id", secret: "client-secret"},
      sub: "owner-id",
      resource_owner: %ResourceOwner{sub: "owner-id", username: "alice"},
      scope: "read",
      credentials: "alice:password"
    }

    %{params: params}
  end

  @tag :skip
  test "Basic values are deterministic and contain a SHA-256 hex digest", %{params: params} do
    value = TokenGenerator.generate_basic(params)

    assert value =~ ~r/^basic-[0-9A-F]{64}$/
    assert TokenGenerator.generate_basic(params) == value
    refute value =~ params.credentials
  end

  @tag :skip
  test "changing the client, subject, resource owner or scope changes the token", %{
    params: params
  } do
    original = TokenGenerator.generate_basic(params)

    for changed <- [
          %{params | client: %{params.client | id: "other-client"}},
          %{params | sub: "other-subject"},
          %{params | resource_owner: %{params.resource_owner | sub: "other-owner"}},
          %{params | resource_owner: %{params.resource_owner | username: "bob"}},
          %{params | scope: "write"}
        ] do
      refute TokenGenerator.generate_basic(changed) == original
    end
  end

  @tag :skip
  test "unrelated token attributes do not affect the Basic value", %{params: params} do
    extended =
      Map.merge(params, %{
        client: %{params.client | secret: "other-secret"},
        credentials: "alice:new-password",
        value: "old-value",
        expires_at: 123,
        metadata: "ignored"
      })

    assert TokenGenerator.generate_basic(extended) == TokenGenerator.generate_basic(params)
  end

  @tag :skip
  test "Basic access tokens use deterministic generation", %{params: params} do
    token =
      struct!(
        Token,
        Map.merge(params |> Map.delete(:credentials), %{
          type: "access_token",
          authorization_details: [%{"type" => "openid_credential", "format" => "basic_auth"}]
        })
      )

    assert TokenGenerator.generate(:access_token, token) ==
             TokenGenerator.generate_basic(Map.from_struct(token))
  end

  test "ordinary access tokens and refresh tokens use random generation", %{params: params} do
    basic_token = %Token{
      type: "access_token",
      client: params.client,
      resource_owner: params.resource_owner,
      authorization_details: [%{"type" => "openid_credential", "format" => "basic_auth"}]
    }

    for {type, token} <- [
          {:access_token, %{basic_token | authorization_details: nil}},
          {:access_token, %{basic_token | authorization_details: [%{"type" => "basic_auth"}]}},
          {:access_token, %{basic_token | authorization_details: [%{"format" => "other"}]}},
          {:refresh_token, basic_token}
        ] do
      first = TokenGenerator.generate(type, token)
      second = TokenGenerator.generate(type, token)

      assert is_binary(first) and byte_size(first) > 0
      refute String.starts_with?(first, "basic-")
      refute first == second
    end
  end
end
