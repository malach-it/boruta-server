defmodule BorutaWeb.Integration.OpenidConnectTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.ClientsAdapter
  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Client
  alias Boruta.Ecto.ClientStore
  alias Boruta.Oauth
  alias Boruta.Oauth.Authorization.AccessToken
  alias Boruta.Oauth.TokenResponse
  alias BorutaAuth.ClientBlsKeyPair
  alias BorutaAuth.PhiAccessToken
  alias BorutaIdentity.Repo
  alias BorutaWeb.Oauth.TokenController
  alias BorutaIdentityWeb.Authenticable

  describe "OpenID Connect flows" do
    setup %{conn: conn} do
      public_client = Admin.get_client!(ClientsAdapter.public!().id)

      {:ok, _client} =
        Admin.update_client(public_client, %{supported_grant_types: Oauth.Client.grant_types()})

      ClientStore.invalidate_public()

      resource_owner = user_fixture()
      redirect_uri = "http://redirect.uri"
      client = insert(:client, redirect_uris: [redirect_uri])
      scope = insert(:scope, public: true)

      {:ok,
       conn: conn,
       client: client,
       redirect_uri: redirect_uri,
       resource_owner: resource_owner,
       scope: scope}
    end

    test "redirect to login with prompt=login", %{conn: conn} do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            prompt: "login"
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "redirects public client to login with prompt=login", %{
      conn: conn,
      redirect_uri: redirect_uri
    } do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: "did:key:test",
            redirect_uri: redirect_uri,
            client_metadata: "{}",
            prompt: "login",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "returns an error with prompt=none without any current_user", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/error=login_required/
    end

    test "ignores unsigned request claims", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      unsigned_request =
        unsigned_jwt(%{
          "client_id" => "bad-client",
          "redirect_uri" => "http://evil.redirect.uri"
        })

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            request: unsigned_request,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/#{redirect_uri}/
      refute redirected_to(conn) =~ "http://evil.redirect.uri"
      assert redirected_to(conn) =~ ~r/error=login_required/
    end

    test "authorizes with prompt=none with anonymous client (verifiable presentation - wallet)",
         %{
           conn: conn,
           redirect_uri: redirect_uri
         } do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "vp_token",
            client_id: "did:key:test",
            redirect_uri: redirect_uri,
            client_metadata: "{}",
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/request=/

      assert redirected_to(conn) =~
               ~r/redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fopenid%2Fdirect_post%2F/

      assert redirected_to(conn) =~ ~r/#{redirect_uri}/
    end

    test "authorizes with prompt=none with anonymous client (siopv2 - wallet)", %{
      conn: conn,
      redirect_uri: redirect_uri
    } do
      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: "did:key:test",
            redirect_uri: redirect_uri,
            client_metadata: "{}",
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/request=/

      assert redirected_to(conn) =~
               ~r/redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fopenid%2Fdirect_post%2F/

      assert redirected_to(conn) =~ ~r/#{redirect_uri}/
    end

    test "returns an error with prompt=none without any current_user (preauthorized)", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri
    } do
      request_param =
        Authenticable.request_param(
          get(
            conn,
            Routes.authorize_path(conn, :authorize, %{
              response_type: "id_token",
              client_id: client.id,
              redirect_uri: redirect_uri,
              prompt: "none",
              scope: "openid",
              nonce: "nonce"
            })
          )
        )

      conn =
        init_test_session(conn, session_chosen: true, preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/error=login_required/
    end

    test "authorize with prompt='none' and a current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      metadata_scope = "metadata:age"
      insert(:scope, name: metadata_scope, public: true)

      {:ok, _backend} =
        resource_owner.backend
        |> Ecto.Changeset.change(%{
          metadata_fields: [
            %{
              "attribute_name" => "age",
              "phi_data_token" => true,
              "scopes" => [metadata_scope],
              "user_editable" => true
            }
          ]
        })
        |> Repo.update()

      {:ok, phi_data_token} =
        BorutaAuth.BlsKeyPair.phi_data_token(resource_owner.bls_public_key, "age", 42)

      {:ok, resource_owner} =
        resource_owner
        |> Ecto.Changeset.change(%{
          metadata: %{
            "age" => %{
              "value" => 42,
              "status" => "valid",
              "display" => [],
              "phi_data_token" => phi_data_token
            }
          }
        })
        |> Repo.update()

      {:ok, client_key_pair} = ClientBlsKeyPair.get_or_create(client.id)

      request_param =
        Authenticable.request_param(
          get(
            conn,
            Routes.authorize_path(conn, :authorize, %{
              response_type: "id_token",
              client_id: client.id,
              redirect_uri: redirect_uri,
              prompt: "none",
              scope: "openid #{metadata_scope}",
              nonce: "nonce"
            })
          )
        )

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true, preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid #{metadata_scope}",
            nonce: "nonce"
          })
        )

      assert url = redirected_to(conn)

      assert [_, id_token] =
               Regex.run(
                 ~r/#{redirect_uri}#id_token=(.+)/,
                 url
               )

      assert {:ok,
              %{
                "age" => 42,
                "_proof" => %{
                  "age" => %{
                    "phi_data_token" => ^phi_data_token,
                    "phi_access_token" => phi_access_token
                  }
                }
              }} = Joken.peek_claims(id_token)

      assert {:ok, _claims} =
               Boruta.Oauth.Client.Crypto.verify_id_token_signature(
                 id_token,
                 JOSE.JWK.from_pem(client.public_key) |> JOSE.JWK.to_map()
               )

      assert PhiAccessToken.verify_with_private_keys(
               phi_access_token,
               phi_data_token,
               resource_owner.bls_private_key,
               client_key_pair.private_key
             )
    end

    test "returns an error with prompt=none when current_user is not preauthorized", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(session_chosen: true)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            prompt: "none",
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert redirected_to(conn) =~ ~r/error=login_required/
      assert redirected_to(conn) =~ ~r/User\+authorization\+is\+required/
    end

    test "logs in with an expired max_age and current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: "openid",
            nonce: "nonce",
            max_age: 0
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "logs in public client with an expired max_age and current_user", %{
      conn: conn,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      conn =
        conn
        |> log_in(resource_owner)

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "code",
            client_id: "did:key:test",
            redirect_uri: redirect_uri,
            client_metadata: "{}",
            scope: "openid",
            nonce: "nonce",
            max_age: 0
          })
        )

      assert redirected_to(conn) =~ "/users/log_out"
    end

    test "redirects to redirect_uri session with a non expired max_age and current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      request_param =
        Authenticable.request_param(
          get(
            conn,
            Routes.authorize_path(conn, :authorize, %{
              response_type: "id_token",
              client_id: client.id,
              redirect_uri: redirect_uri,
              scope: "openid",
              nonce: "nonce",
              max_age: 10
            })
          )
        )

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: "openid",
            nonce: "nonce",
            max_age: 10
          })
        )

      assert url = redirected_to(conn)

      assert [_, _id_token] =
               Regex.run(
                 ~r/#{redirect_uri}#id_token=(.+)/,
                 url
               )
    end

    test "does not expire login with a malformed max_age and current_user", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      redirect_uri: redirect_uri
    } do
      request_param =
        Authenticable.request_param(
          get(
            conn,
            Routes.authorize_path(conn, :authorize, %{
              response_type: "id_token",
              client_id: client.id,
              redirect_uri: redirect_uri,
              scope: "openid",
              nonce: "nonce",
              max_age: "0invalid"
            })
          )
        )

      conn =
        conn
        |> log_in(resource_owner)
        |> init_test_session(preauthorizations: %{request_param => true})

      conn =
        get(
          conn,
          Routes.authorize_path(conn, :authorize, %{
            response_type: "id_token",
            client_id: client.id,
            redirect_uri: redirect_uri,
            scope: "openid",
            nonce: "nonce",
            max_age: "0invalid"
          })
        )

      assert url = redirected_to(conn)
      refute url =~ "/users/log_out"

      assert [_, _id_token] =
               Regex.run(
                 ~r/#{redirect_uri}#id_token=(.+)/,
                 url
               )
    end
  end

  describe "jwks endpoints" do
    test "returns public client key", %{conn: conn} do
      conn = get(conn, Routes.jwks_path(conn, :jwks_index))

      assert %{"keys" => keys} = json_response(conn, 200)
      assert Enum.count(keys) == 1
    end

    test "returns all clients keys", %{conn: conn} do
      %Client{} = insert(:client)

      conn = get(conn, Routes.jwks_path(conn, :jwks_index))

      assert keys = json_response(conn, 200)["keys"]
      assert Enum.find(keys, fn %{"kid" => kid} -> kid == "Ac9ufCpgwReXGJ6LI" end)
    end
  end

  describe "userinfo" do
    test "returns userinfo", %{conn: conn} do
      sub = user_fixture().id

      token = insert(:token, sub: sub)

      conn =
        conn
        |> put_req_header("authorization", "bearer #{token.value}")
        |> post(Routes.userinfo_path(conn, :userinfo))

      assert json_response(conn, 200)
    end

    test "returns one sequential phi accumulator per consented metadata attribute", %{conn: conn} do
      backend =
        BorutaIdentity.Factory.insert(:backend,
          metadata_fields: [
            %{
              "attribute_name" => "age",
              "phi_data_token" => true,
              "scopes" => ["profile"],
              "user_editable" => true
            },
            %{
              "attribute_name" => "city",
              "phi_data_token" => true,
              "scopes" => ["profile"],
              "user_editable" => true
            }
          ]
        )

      user = user_fixture(%{backend: backend})

      {:ok, phi_data_token} =
        BorutaAuth.BlsKeyPair.phi_data_token(user.bls_public_key, "age", 42)

      {:ok, city_phi_data_token} =
        BorutaAuth.BlsKeyPair.phi_data_token(user.bls_public_key, "city", "Paris")

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{
          metadata: %{
            "age" => %{
              "value" => 42,
              "status" => "valid",
              "display" => [],
              "phi_data_token" => phi_data_token
            },
            "city" => %{
              "value" => "Paris",
              "status" => "valid",
              "display" => [],
              "phi_data_token" => city_phi_data_token
            }
          }
        })
        |> Repo.update()

      token = insert(:token, sub: user.id, scope: "profile")
      {:ok, client_key_pair} = ClientBlsKeyPair.get_or_create(token.client.id)

      {:ok, _client} =
        token.client
        |> Ecto.Changeset.change(%{userinfo_signed_response_alg: "HS512"})
        |> BorutaAuth.Repo.update()

      conn =
        conn
        |> put_req_header("authorization", "bearer #{token.value}")
        |> post(Routes.userinfo_path(conn, :userinfo))

      assert {:ok, claims} = Joken.peek_claims(response(conn, 200))

      assert %{
               "age" => 42,
               "city" => "Paris",
               "_proof" => %{
                 "age" => %{
                   "type" => "Bls12381G2SequentialAccumulator",
                   "phi_data_token" => ^phi_data_token,
                   "phi_access_token" => phi_access_token,
                   "resource_owner_bls_did_key" => resource_owner_did,
                   "resource_owner_key_proof" => %{
                     "type" => "Bls12381G2RemainingPartyProof",
                     "value" => resource_owner_key_proof
                   }
                 },
                 "city" => %{
                   "phi_data_token" => ^city_phi_data_token,
                   "phi_access_token" => city_phi_access_token
                 }
               }
             } = claims

      assert resource_owner_did == user.bls_did_key

      assert PhiAccessToken.verify_remaining_proof(
               phi_access_token,
               phi_data_token,
               resource_owner_key_proof,
               client_key_pair.public_key,
               user.bls_public_key
             )

      assert PhiAccessToken.verify_with_private_keys(
               phi_access_token,
               phi_data_token,
               user.bls_private_key,
               client_key_pair.private_key
             )

      assert PhiAccessToken.verify_remaining(
               phi_access_token,
               phi_data_token,
               client_key_pair.private_key,
               user.bls_public_key
             )

      assert PhiAccessToken.verify_remaining(
               phi_access_token,
               phi_data_token,
               user.bls_private_key,
               client_key_pair.public_key
             )

      assert PhiAccessToken.verify_with_private_keys(
               city_phi_access_token,
               city_phi_data_token,
               user.bls_private_key,
               client_key_pair.private_key
             )
    end

    test "does not return phi access proofs outside the consented scope", %{conn: conn} do
      backend =
        BorutaIdentity.Factory.insert(:backend,
          metadata_fields: [
            %{
              "attribute_name" => "age",
              "phi_data_token" => true,
              "scopes" => ["metadata:age"],
              "user_editable" => true
            }
          ]
        )

      user = user_fixture(%{backend: backend})

      {:ok, phi_data_token} =
        BorutaAuth.BlsKeyPair.phi_data_token(user.bls_public_key, "age", 42)

      {:ok, _user} =
        user
        |> Ecto.Changeset.change(%{
          metadata: %{
            "age" => %{
              "value" => 42,
              "status" => "valid",
              "display" => [],
              "phi_data_token" => phi_data_token
            }
          }
        })
        |> Repo.update()

      token = insert(:token, sub: user.id)
      {:ok, _client_key_pair} = ClientBlsKeyPair.get_or_create(token.client.id)

      conn =
        conn
        |> put_req_header("authorization", "bearer #{token.value}")
        |> post(Routes.userinfo_path(conn, :userinfo))

      refute Map.has_key?(json_response(conn, 200), "_proof")
    end

    test "returns userinfo as jwt", %{conn: conn} do
      sub = user_fixture().id

      token = insert(:token, sub: sub)

      {:ok, _client} =
        Ecto.Changeset.change(token.client, %{userinfo_signed_response_alg: "HS512"})
        |> BorutaAuth.Repo.update()

      conn =
        conn
        |> put_req_header("authorization", "bearer #{token.value}")
        |> post(Routes.userinfo_path(conn, :userinfo))

      assert String.starts_with?(response(conn, 200), "ey")
    end
  end

  describe "ID token phi proofs" do
    test "carries resource-owner proofs into token endpoint ID-token claims", %{conn: conn} do
      metadata_scope = "metadata:age"

      backend =
        BorutaIdentity.Factory.insert(:backend,
          metadata_fields: [
            %{
              "attribute_name" => "age",
              "phi_data_token" => true,
              "scopes" => [metadata_scope],
              "user_editable" => true
            }
          ]
        )

      user = user_fixture(%{backend: backend})

      {:ok, phi_data_token} =
        BorutaAuth.BlsKeyPair.phi_data_token(user.bls_public_key, "age", 42)

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{
          metadata: %{
            "age" => %{
              "value" => 42,
              "status" => "valid",
              "display" => [],
              "phi_data_token" => phi_data_token
            }
          }
        })
        |> Repo.update()

      persisted_token = insert(:token, sub: user.id, scope: "openid #{metadata_scope}")
      {:ok, token} = AccessToken.authorize(value: persisted_token.value)
      {:ok, client_key_pair} = ClientBlsKeyPair.get_or_create(token.client.id)

      id_token =
        Boruta.Oauth.IdToken.generate(
          %{token: token},
          nil
        )

      conn =
        TokenController.token_success(conn, %TokenResponse{
          expires_in: 3600,
          token: token,
          id_token: id_token.value
        })

      assert %{"id_token" => proofed_id_token} = json_response(conn, 200)

      assert {:ok,
              %{
                "_proof" => %{
                  "age" => %{
                    "phi_data_token" => ^phi_data_token,
                    "phi_access_token" => phi_access_token
                  }
                }
              }} = Joken.peek_claims(proofed_id_token)

      assert {:ok, _claims} =
               Boruta.Oauth.Client.Crypto.verify_id_token_signature(
                 proofed_id_token,
                 JOSE.JWK.from_pem(token.client.public_key) |> JOSE.JWK.to_map()
               )

      assert PhiAccessToken.verify_with_private_keys(
               phi_access_token,
               phi_data_token,
               user.bls_private_key,
               client_key_pair.private_key
             )
    end
  end

  describe "discovery 1.0" do
    test "returns required keys", %{conn: conn} do
      BorutaIdentity.Factory.insert(:backend,
        verifiable_credentials: [
          %{
            "display" => %{
              "background_color" => "#53b29f",
              "logo" => %{
                "alt_text" => "Boruta PoC logo",
                "url" => "https://io.malach.it/assets/images/logo.png"
              },
              "name" => "Federation credential PoC",
              "text_color" => "#FFFFFF"
            },
            "claims" => [%{"name" => "claim", "label" => "label"}],
            "credential_identifier" => "FederatedAttributes",
            "format" => "jwt_vc",
            "types" => "VerifiableCredential BorutaCredential"
          }
        ]
      )

      Boruta.Factory.insert(:scope, name: "well_known")

      conn = get(conn, Routes.openid_path(conn, :well_known))

      assert json_response(conn, 200) == %{
               "authorization_endpoint" => "http://localhost:4000/oauth/authorize",
               "credential_endpoint" => "http://localhost:4000/openid/credential",
               "defered_credential_endpoint" => "http://localhost:4000/openid/defered-credential",
               "pushed_authorization_request_endpoint" =>
                 "http://localhost:4000/oauth/pushed_authorization_request",
               "credential_issuer" => "http://localhost:4000",
               "credentials_supported" => [],
               "credential_configurations_supported" => %{
                 "FederatedAttributes" => %{
                   "credential_definition" => %{
                     "credentialSubject" => %{"claim" => [%{"name" => "label"}]},
                     "type" => ["VerifiableCredential", "BorutaCredential"]
                   },
                   "credential_signing_alg_values_supported" => [
                     "ES256",
                     "ES384",
                     "ES512",
                     "RS256",
                     "RS384",
                     "RS512",
                     "HS256",
                     "HS384",
                     "HS512",
                     "EdDSA"
                   ],
                   "cryptographic_binding_methods_supported" => ["did:jwk", "did:key"],
                   "display" => [
                     %{
                       "background_color" => "#53b29f",
                       "locale" => "en-US",
                       "logo" => %{
                         "alt_text" => "Boruta PoC logo",
                         "url" => "https://io.malach.it/assets/images/logo.png"
                       },
                       "name" => "Federation credential PoC",
                       "text_color" => "#FFFFFF"
                     }
                   ],
                   "format" => "jwt_vc",
                   "scope" => "FederatedAttributes"
                 }
               },
               "grant_types_supported" => [
                 "client_credentials",
                 "password",
                 "implicit",
                 "authorization_code",
                 "refresh_token"
               ],
               "id_token_signing_alg_values_supported" => [
                 "ES256",
                 "ES384",
                 "ES512",
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512",
                 "EdDSA"
               ],
               "issuer" => "http://localhost:4000",
               "jwks_uri" => "http://localhost:4000/openid/jwks",
               # "registration_endpoint" => "http://localhost:4000/openid/register",
               "request_object_signing_alg_values_supported" => [
                 "ES256",
                 "ES384",
                 "ES512",
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512",
                 "EdDSA"
               ],
               "response_modes_supported" => ["query", "fragment"],
               "response_types_supported" => [
                 "code",
                 "token",
                 "id_token",
                 "code token",
                 "code id_token",
                 "token id_token",
                 "code id_token token"
               ],
               "scopes_supported" => ["well_known"],
               "subject_types_supported" => ["public"],
               "token_endpoint" => "http://localhost:4000/oauth/token",
               "token_endpoint_auth_methods_supported" => [
                 "client_secret_basic",
                 "client_secret_post",
                 "client_secret_jwt",
                 "private_key_jwt"
               ],
               "userinfo_endpoint" => "http://localhost:4000/oauth/userinfo",
               "userinfo_signing_alg_values_supported" => [
                 "ES256",
                 "ES384",
                 "ES512",
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512",
                 "EdDSA"
               ]
             }
    end
  end

  # describe "dynamic registration" do
  #   test "returns an error when data is invalid", %{conn: conn} do
  #     conn =
  #       post(conn, Routes.dynamic_registration_path(conn, :register_client), %{redirect_uris: nil})

  #     assert json_response(conn, 400) == %{
  #              "error" => "invalid_client_metadata",
  #              "error_description" => "redirect_uris : can't be blank"
  #            }
  #   end

  #   test "registers client", %{conn: conn} do
  #     conn =
  #       post(conn, Routes.dynamic_registration_path(conn, :register_client), %{
  #         redirect_uris: ["https://test.uri"]
  #       })

  #     assert %{
  #              "client_id" => client_id,
  #              "client_secret" => client_secret,
  #              "client_secret_expires_at" => 0
  #            } = json_response(conn, 201)

  #     assert client_id
  #     assert client_secret
  #   end

  #   test "creates associated identity provider", %{conn: conn} do
  #     conn =
  #       post(conn, Routes.dynamic_registration_path(conn, :register_client), %{
  #         redirect_uris: ["https://test.uri"]
  #       })

  #     assert %{
  #              "client_id" => client_id
  #            } = json_response(conn, 201)

  #     assert %ClientIdentityProvider{identity_provider_id: identity_provider_id} =
  #              BorutaIdentity.Repo.get_by(ClientIdentityProvider, client_id: client_id)

  #     assert BorutaIdentity.Repo.get!(IdentityProvider, identity_provider_id)
  #   end
  # end

  defp unsigned_jwt(claims) do
    header = %{"alg" => "none"} |> Jason.encode!() |> Base.url_encode64(padding: false)
    payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    header <> "." <> payload <> "."
  end
end
