defmodule BorutaWeb.DidControllerTest do
  use BorutaWeb.ConnCase

  import BorutaWeb.Factory

  alias Boruta.Oauth.Client
  alias Boruta.Openid.VerifiableCredentials

  @status_token_ttl 3_600

  describe "GET /did/resolve_status/:status" do
    for status <- [:valid, :suspended, :revoked] do
      test "resolves a #{status} status using the client's private key identifier", %{
        conn: conn
      } do
        client = insert(:client)

        token =
          client.private_key
          |> Client.Crypto.kid_from_private_key()
          |> VerifiableCredentials.Status.generate_status_token(
            @status_token_ttl,
            unquote(status)
          )

        conn = get(conn, Routes.did_path(conn, :resolve_status, token))

        assert response(conn, 200) == Atom.to_string(unquote(status))
      end
    end

    test "resolves a status using the client's DID verification method", %{conn: conn} do
      insert(:client)
      did = "did:key:z6Mktest"
      insert(:client, did: did)

      token =
        VerifiableCredentials.Status.generate_status_token(
          "#{did}#z6Mktest",
          @status_token_ttl,
          :suspended
        )

      conn = get(conn, Routes.did_path(conn, :resolve_status, token))

      assert response(conn, 200) == "suspended"
    end

    test "returns expired for a well-formed status token that no client can verify", %{conn: conn} do
      insert(:client)

      token =
        VerifiableCredentials.Status.generate_status_token(
          "unknown-client",
          @status_token_ttl,
          :valid
        )

      conn = get(conn, Routes.did_path(conn, :resolve_status, token))

      assert response(conn, 200) == "expired"
    end

    test "returns invalid for a malformed status token", %{conn: conn} do
      insert(:client)

      conn = get(conn, Routes.did_path(conn, :resolve_status, "malformed"))

      assert response(conn, 200) == "invalid"
    end
  end
end
