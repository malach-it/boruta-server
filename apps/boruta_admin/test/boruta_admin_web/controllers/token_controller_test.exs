defmodule BorutaAdminWeb.TokenControllerTest do
  use BorutaAdminWeb.ConnCase

  import Boruta.Factory

  alias Boruta.Ecto.Token
  alias Boruta.Oauth.Client
  alias Boruta.Openid.VerifiablePresentations
  alias BorutaAuth.Repo
  alias BorutaIdentity.Factory, as: IdentityFactory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_token_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "show" do
    @tag authorized: ["tokens:read:all"]
    test "returns a token", %{conn: conn} do
      token = insert(:token)

      response =
        conn
        |> get(Routes.admin_token_path(conn, :show, token.id))
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["value"] == token.value
    end

    @tag authorized: ["tokens:read:all"]
    test "keeps previous codes in response", %{conn: conn} do
      code = insert(:token, type: "code", value: "authorization-code")
      token = insert(:token, previous_code: code.value)

      response =
        conn
        |> get(Routes.admin_token_path(conn, :show, token.id))
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["previous_codes"] |> Enum.map(& &1["value"]) == ["authorization-code"]
    end
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_token_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["tokens:read:all"]
    test "lists paginated tokens", %{conn: conn} do
      first_token = insert(:token, scope: "first")
      second_token = insert(:token, scope: "second")

      conn = get(conn, Routes.admin_token_path(conn, :index), %{"page_size" => 1})
      response = json_response(conn, 200)

      assert response["page_number"] == 1
      assert response["page_size"] == 1
      assert response["total_entries"] == 3
      assert response["total_pages"] == 3
      assert response["type_counts"]["access_token"] == 3
      assert is_list(response["scopes"])
      assert [token] = response["data"]
      assert token["id"] in [first_token.id, second_token.id]
      assert token["type"] == "access_token"
      assert token["value"]
      assert token["scope"] in [["first"], ["second"], []]
      assert token["client"]["id"]
    end

    @tag authorized: ["tokens:read:all"]
    test "searches tokens by sub, refresh token, value, and username", %{conn: conn} do
      sub_token = insert(:token, sub: "subjectalpha")
      refresh_token = insert(:token, refresh_token: "refreshbravo")
      value_token = insert(:token, value: "valuecharlie")
      user = insert_token_search_user(username: "userdelta")
      user_token = insert(:token, sub: user.id)

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "subjectalpha"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [sub_token.id]

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "refreshbravo"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [refresh_token.id]

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "valuecharlie"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [value_token.id]

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "userdelta"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [user_token.id]
    end

    @tag authorized: ["tokens:read:all"]
    test "sorts searched tokens by word similarity", %{conn: conn} do
      exact_token =
        insert(:token,
          value: "targetword",
          inserted_at: ~U[2026-01-01 00:00:00Z],
          updated_at: ~U[2026-01-01 00:00:00Z]
        )

      insert(:token,
        value: "zzztargetwordzzz",
        inserted_at: ~U[2026-01-02 00:00:00Z],
        updated_at: ~U[2026-01-02 00:00:00Z]
      )

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "targetword"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [exact_token.id]
    end

    @tag authorized: ["tokens:read:all"]
    test "searches tokens with the configured word similarity threshold", %{conn: conn} do
      token = insert(:token, value: "specific")

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"q" => "specific"})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [token.id]
    end

    @tag authorized: ["tokens:read:all"]
    test "filters tokens by client", %{conn: conn} do
      client = insert(:client)
      other_client = insert(:client)
      token = insert(:token, client: client)
      insert(:token, client: other_client)

      assert conn
             |> get(Routes.admin_token_path(conn, :index), %{"client_id" => client.id})
             |> json_response(200)
             |> Map.get("data")
             |> Enum.map(& &1["id"]) == [token.id]
    end

    @tag authorized: ["tokens:read:all"]
    test "filters tokens by type", %{conn: conn} do
      token = insert(:token, type: "code")
      insert(:token, type: "access_token")

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"type" => "code"})
        |> json_response(200)

      assert response["data"] |> Enum.map(& &1["id"]) == [token.id]
      assert response["types"] == ["access_token", "code"]
      assert response["type_counts"] == %{"code" => 1}
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes issued token counts by type according to filters", %{conn: conn} do
      first_code =
        insert(:token,
          type: "code",
          inserted_at: ~U[2026-01-01 00:00:00.123456Z],
          updated_at: ~U[2026-01-01 00:00:00.123456Z]
        )

      insert(:token,
        type: "code",
        inserted_at: ~U[2026-01-01 00:00:00.654321Z],
        updated_at: ~U[2026-01-01 00:00:00.654321Z]
      )

      insert(:token,
        type: "code",
        inserted_at: ~U[2026-01-01 00:00:02Z],
        updated_at: ~U[2026-01-01 00:00:02Z]
      )

      insert(:token,
        type: "access_token",
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      )

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{
          "type" => first_code.type,
          "start_at" => "2026-01-01T00:00:00Z",
          "end_at" => "2026-01-01T00:00:01Z"
        })
        |> json_response(200)

      assert response["token_counts_time_scale_unit"] == "minute"

      assert response["token_counts"] == %{
               "code" => %{
                 "2026-01-01T00:00:00.000000Z" => 2
               }
             }
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes issued token counts in separate type series", %{conn: conn} do
      insert(:token,
        type: "code",
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      )

      insert(:token,
        type: "access_token",
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      )

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{
          "start_at" => "2026-01-01T00:00:00Z",
          "end_at" => "2026-01-01T00:00:01Z"
        })
        |> json_response(200)

      assert response["token_counts"] == %{
               "access_token" => %{
                 "2026-01-01T00:00:00.000000Z" => 1
               },
               "code" => %{
                 "2026-01-01T00:00:00.000000Z" => 1
               }
             }
    end

    @tag authorized: ["tokens:read:all"]
    test "groups issued token counts by day for a month range", %{conn: conn} do
      token =
        insert(:token,
          type: "code",
          inserted_at: ~U[2026-01-01 12:34:56Z],
          updated_at: ~U[2026-01-01 12:34:56Z]
        )

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{
          "type" => token.type,
          "start_at" => "2025-12-15T00:00:00Z",
          "end_at" => "2026-01-15T00:00:00Z"
        })
        |> json_response(200)

      assert response["token_counts_time_scale_unit"] == "day"

      assert response["token_counts"] == %{
               "code" => %{
                 "2026-01-01T00:00:00.000000Z" => 1
               }
             }
    end

    @tag authorized: ["tokens:read:all"]
    test "filters tokens by granted or requested scope", %{conn: conn} do
      requested_scope_token =
        insert(:token, scope: "granted:read", requested_scope: "token:read token:write")

      granted_scope_token = insert(:token, scope: "token:write", requested_scope: "token:read")
      insert(:token, scope: "token:read", requested_scope: "token:read")

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"scope" => "token:write"})
        |> json_response(200)

      assert response["data"] |> Enum.map(& &1["id"]) |> Enum.sort() ==
               [requested_scope_token.id, granted_scope_token.id] |> Enum.sort()

      assert "granted:read" in response["scopes"]
      assert "token:write" in response["scopes"]
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes token user when sub matches an user", %{conn: conn} do
      user = IdentityFactory.insert(:user)
      token = insert(:token, sub: user.id)

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"q" => token.value})
        |> json_response(200)

      assert %{
               "id" => user.id,
               "uid" => user.uid,
               "username" => user.username,
               "blocked" => false
             } == response["data"] |> List.first() |> Map.get("user")
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes code chain fields", %{conn: conn} do
      token =
        insert(:token,
          response_type: "code",
          previous_code: "previous-code",
          previous_token: "previous-token",
          agent_token: "agent-token"
        )

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"q" => token.value})
        |> json_response(200)
        |> Map.get("data")
        |> Enum.find(&(&1["id"] == token.id))

      assert response["response_type"] == "code"
      assert response["previous_code"] == "previous-code"
      assert response["previous_token"] == "previous-token"
      assert response["agent_token"] == "agent-token"
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes id token and verified claims", %{conn: conn} do
      client = insert(:client)
      {_, jwk} = JOSE.JWK.from_pem(client.public_key) |> JOSE.JWK.to_map()

      signer =
        Joken.Signer.create("RS512", %{"pem" => client.private_key}, %{
          "jwk" => jwk
        })

      presentation_definition = %{
        "id" => "codex_hook_input",
        "input_descriptors" => [
          %{
            "id" => "codex_hook_input",
            "constraints" => %{
              "fields" => [
                %{
                  "path" => ["$.credential_type"],
                  "filter" => %{"type" => "string", "const" => "codex_hook_input"}
                }
              ]
            }
          }
        ]
      }

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{
            "sub" => "did:example:id",
            "agent_wallet_url" => "http://127.0.0.1:8766/accounts/wallet",
            "hook_presentation_definition" => presentation_definition
          },
          signer
        )

      token = insert(:token, id_token: id_token, client: client)

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"q" => token.value})
        |> json_response(200)
        |> Map.get("data")
        |> List.first()

      assert response["id_token"] == id_token
      assert response["id_token_claims"]["verified"] == true
      assert response["id_token_claims"]["claims"]["sub"] == "did:example:id"

      verifiable_presentation_url = response["id_token_claims"]["verifiable_presentation_url"]
      assert verifiable_presentation_url =~ "http://127.0.0.1:8766/accounts/wallet?"

      query = URI.decode_query(URI.parse(verifiable_presentation_url).query)
      assert query["response_type"] == "vp_token"
      assert query["response_mode"] == "direct_post"
      assert query["client_id"] == client.id
      assert query["scope"] == "openid"
      assert query["redirect_uri"] =~ "/oauth/tokens/#{token.id}/user-data"
      assert is_binary(query["request"])
      refute Map.has_key?(query, "presentation_definition")

      {_, public_jwk} = JOSE.JWK.from_pem(client.public_key) |> JOSE.JWK.to_map()

      assert {:ok, request_claims} =
               Client.Crypto.verify_id_token_signature(query["request"], public_jwk)

      assert request_claims["response_type"] == "vp_token"
      assert request_claims["response_mode"] == "direct_post"
      assert request_claims["client_id"] == Boruta.Config.issuer()
      assert request_claims["aud"] == client.id
      assert request_claims["scope"] == "openid"
      assert request_claims["redirect_uri"] == query["redirect_uri"]
      assert request_claims["presentation_definition"] == presentation_definition
      assert is_binary(request_claims["nonce"])
      assert request_claims["nonce"] != ""

      refute Map.has_key?(response, "vp_token")
      refute Map.has_key?(response, "vp_token_claims")
    end

    @tag authorized: ["tokens:read:all"]
    test "exposes previous codes chain", %{conn: conn} do
      root_code = insert(:token, type: "code", value: "root-code")

      middle_code =
        insert(:token, type: "code", value: "middle-code", previous_code: root_code.value)

      token = insert(:token, previous_code: middle_code.value)

      response =
        conn
        |> get(Routes.admin_token_path(conn, :index), %{"q" => token.value})
        |> json_response(200)
        |> Map.get("data")
        |> List.first()

      assert response["id"] == token.id
      assert response["previous_code"] == "middle-code"
      assert response["previous_codes"] |> Enum.map(& &1["value"]) == ["root-code", "middle-code"]
      assert response["previous_codes"] |> Enum.map(& &1["type"]) == ["code", "code"]
    end
  end

  describe "revoke" do
    @tag authorized: ["tokens:read:all"]
    test "revokes active access token", %{conn: conn} do
      token = insert(:token, type: "access_token", expires_at: :os.system_time(:seconds) + 60)

      response =
        conn
        |> post("/api/tokens/#{token.id}/revoke")
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["revoked_at"]
      assert Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "keeps previous codes in revoke response", %{conn: conn} do
      code = insert(:token, type: "code", value: "authorization-code")

      token =
        insert(:token,
          type: "access_token",
          previous_code: code.value,
          expires_at: :os.system_time(:seconds) + 60
        )

      response =
        conn
        |> post("/api/tokens/#{token.id}/revoke")
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["revoked_at"]
      assert response["previous_codes"] |> Enum.map(& &1["value"]) == ["authorization-code"]
    end

    @tag authorized: ["tokens:read:all"]
    test "revokes active code", %{conn: conn} do
      token = insert(:token, type: "code", expires_at: :os.system_time(:seconds) + 60)

      response =
        conn
        |> post("/api/tokens/#{token.id}/revoke")
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["revoked_at"]
      assert Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "revokes active agent token", %{conn: conn} do
      token = insert(:token, type: "agent_token", expires_at: :os.system_time(:seconds) + 60)

      response =
        conn
        |> post("/api/tokens/#{token.id}/revoke")
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["revoked_at"]
      assert Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "does not revoke expired access token", %{conn: conn} do
      token = insert(:token, type: "access_token", expires_at: :os.system_time(:seconds) - 60)

      assert conn
             |> post("/api/tokens/#{token.id}/revoke")
             |> json_response(400)

      refute Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "does not revoke expired code", %{conn: conn} do
      token = insert(:token, type: "code", expires_at: :os.system_time(:seconds) - 60)

      assert conn
             |> post("/api/tokens/#{token.id}/revoke")
             |> json_response(400)

      refute Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "does not revoke expired agent token", %{conn: conn} do
      token = insert(:token, type: "agent_token", expires_at: :os.system_time(:seconds) - 60)

      assert conn
             |> post("/api/tokens/#{token.id}/revoke")
             |> json_response(400)

      refute Repo.get(Token, token.id).revoked_at
    end

    @tag authorized: ["tokens:read:all"]
    test "does not revoke non access token", %{conn: conn} do
      token = insert(:token, type: "refresh_token", expires_at: :os.system_time(:seconds) + 60)

      assert conn
             |> post("/api/tokens/#{token.id}/revoke")
             |> json_response(400)

      refute Repo.get(Token, token.id).revoked_at
    end
  end
end
