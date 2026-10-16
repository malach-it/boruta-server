defmodule BorutaWeb.Oauth.TokenUserDataTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory

  alias Boruta.Openid.VerifiablePresentations
  alias BorutaAuth.TokenUserData

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "user_data" do
    test "stores user data from a vp_token", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      user_data = %{
        "hook_event_name" => "UserPromptSubmit",
        "prompt" => "present this in the admin dashboard"
      }

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => user_data, "nonce" => nonce, "aud" => client.id},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["user_data"] == user_data
    end

    test "stores user data from a vp_token credential signed by the code id_token cnf", %{
      conn: conn
    } do
      client = insert(:client)
      wallet_client = insert(:client)
      {signer, jwk} = signer_for(client)
      {wallet_signer, _wallet_jwk} = signer_for(wallet_client)

      user_data = %{
        "hook_event_name" => "PreToolUse",
        "tool_name" => "functions.exec_command"
      }

      {:ok, credential, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"user_data" => user_data}, signer)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{
            "vp" => %{"verifiableCredential" => [credential]},
            "nonce" => nonce,
            "aud" => client.id
          },
          wallet_signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(200)
        |> Map.get("data")

      assert response["id"] == token.id
      assert response["user_data"] == user_data
    end

    test "rejects user data signed with a key that does not match the code id_token cnf", %{
      conn: conn
    } do
      client = insert(:client)
      {signer, jwk} = signer_for(client)
      {other_signer, _other_jwk} = generated_signer()

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{"unsafe" => true}, "nonce" => nonce, "aud" => client.id},
          other_signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects valid client credentials for another token client", %{conn: conn} do
      client = insert(:client)
      other_client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{"unsafe" => true}, "nonce" => nonce, "aud" => client.id},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => other_client.id,
          "client_secret" => other_client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects replay when token user data is already present", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      first_user_data = %{"hook_event_name" => "UserPromptSubmit"}
      replay_user_data = %{"hook_event_name" => "PreToolUse"}

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, first_vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => first_user_data, "nonce" => nonce, "aud" => client.id},
          signer
        )

      {:ok, replay_vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => replay_user_data, "nonce" => nonce, "aud" => client.id},
          signer
        )

      conn
      |> post("/oauth/tokens/#{token.id}/user-data", %{
        "vp_token" => first_vp_token,
        "client_id" => client.id,
        "client_secret" => client.secret
      })
      |> json_response(200)

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => replay_vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects user data without expected nonce", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{}, "aud" => client.id},
          signer
        )

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      TokenUserData.ensure_nonce(token)

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects user data with mismatched nonce", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{}, "nonce" => "wrong-nonce", "aud" => client.id},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects user data without expected audience", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{}, "nonce" => nonce},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "rejects user data with mismatched audience", %{conn: conn} do
      client = insert(:client)
      other_client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{}, "nonce" => nonce, "aud" => other_client.id},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => client.secret
        })
        |> json_response(400)

      assert response == "Bad Request"
    end

    test "returns oauth error for invalid client credentials", %{conn: conn} do
      client = insert(:client)
      {signer, jwk} = signer_for(client)

      {:ok, id_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(%{"cnf" => %{"jwk" => jwk}}, signer)

      token = insert(:token, client: client, id_token: id_token)
      nonce = TokenUserData.ensure_nonce(token)

      {:ok, vp_token, _claims} =
        VerifiablePresentations.Token.generate_and_sign(
          %{"user_data" => %{}, "nonce" => nonce, "aud" => client.id},
          signer
        )

      response =
        conn
        |> post("/oauth/tokens/#{token.id}/user-data", %{
          "vp_token" => vp_token,
          "client_id" => client.id,
          "client_secret" => "bad-secret"
        })
        |> json_response(401)

      assert response["error"] == "invalid_client"
      assert is_binary(response["error_description"])
    end
  end

  defp signer_for(client) do
    {_, jwk} = JOSE.JWK.from_pem(client.public_key) |> JOSE.JWK.to_map()

    signer =
      Joken.Signer.create("RS512", %{"pem" => client.private_key}, %{
        "jwk" => jwk
      })

    {signer, jwk}
  end

  defp generated_signer do
    key = JOSE.JWK.generate_key({:rsa, 2048})
    private_pem = JOSE.JWK.to_pem(key)
    {_, jwk} = key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()

    signer =
      Joken.Signer.create("RS512", %{"pem" => private_pem}, %{
        "jwk" => jwk
      })

    {signer, jwk}
  end
end
