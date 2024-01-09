defmodule BorutaWeb.Integration.OpenidConnectTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentityWeb.Authenticable

  alias Boruta.Ecto.Client

  describe "OpenID Connect flows" do
    setup %{conn: conn} do
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
            scope: "openid",
            nonce: "nonce"
          })
        )

      assert url = redirected_to(conn)

      assert [_, _id_token] =
               Regex.run(
                 ~r/#{redirect_uri}#id_token=(.+)/,
                 url
               )
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
  end

  describe "jwks endpoints" do
    test "returns an empty list", %{conn: conn} do
      conn = get(conn, Routes.jwks_path(conn, :jwks_index))

      assert json_response(conn, 200) == %{"keys" => []}
    end

    test "returns all clients keys", %{conn: conn} do
      %Client{} = insert(:client)

      conn = get(conn, Routes.jwks_path(conn, :jwks_index))

      assert %{
               "keys" => [%{"kid" => "Ac9ufCpgwReXGJ6LI", "kty" => "RSA"}]
             } = json_response(conn, 200)
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

      assert response(conn, 200)
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
            "credential_identifier" => "FederatedAttributes",
            "types" => "VerifiableCredential BorutaCredential"
          }
        ]
      )

      conn = get(conn, Routes.openid_path(conn, :well_known))

      assert json_response(conn, 200) == %{
               "authorization_endpoint" => "boruta/oauth/authorize",
               "id_token_signing_alg_values_supported" => [
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512"
               ],
               "issuer" => "boruta",
               "jwks_uri" => "boruta/openid/jwks",
               "registration_endpoint" => "boruta/openid/register",
               "response_types_supported" => [
                 "code",
                 "token",
                 "id_token",
                 "code token",
                 "code id_token",
                 "token id_token",
                 "code id_token token"
               ],
               "response_modes_supported" => ["query", "fragment"],
               "subject_types_supported" => ["public"],
               "token_endpoint_auth_methods_supported" => [
                 "client_secret_basic",
                 "client_secret_post",
                 "client_secret_jwt",
                 "private_key_jwt"
               ],
               "token_endpoint" => "boruta/oauth/token",
               "userinfo_endpoint" => "boruta/oauth/userinfo",
               "userinfo_signing_alg_values_supported" => [
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512"
               ],
               "request_object_signing_alg_values_supported" => [
                 "RS256",
                 "RS384",
                 "RS512",
                 "HS256",
                 "HS384",
                 "HS512"
               ],
               "grant_types_supported" => [
                 "client_credentials",
                 "password",
                 "implicit",
                 "authorization_code",
                 "refresh_token"
               ],
               "credential_endpoint" => "boruta/openid/credential",
               "credential_issuer" => "boruta",
               "credentials_supported" => [
                 %{
                   "cryptographic_binding_methods_supported" => ["did:example"],
                   "display" => [
                     %{
                       "background_color" => "#53b29f",
                       "logo" => %{
                         "alt_text" => "Boruta PoC logo",
                         "url" => "https://io.malach.it/assets/images/logo.png"
                       },
                       "name" => "Federation credential PoC",
                       "text_color" => "#FFFFFF"
                     }
                   ],
                   "format" => "jwt_vc_json",
                   "id" => "FederatedAttributes",
                   "types" => ["VerifiableCredential", "BorutaCredential"]
                 }
               ]
             }
    end
  end

  describe "dynamic registration" do
    test "returns an error when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.dynamic_registration_path(conn, :register_client), %{redirect_uris: nil})

      assert json_response(conn, 400) == %{
               "error" => "invalid_client_metadata",
               "error_description" => "redirect_uris : can't be blank"
             }
    end

    test "registers client", %{conn: conn} do
      conn =
        post(conn, Routes.dynamic_registration_path(conn, :register_client), %{
          redirect_uris: ["https://test.uri"]
        })

      assert %{
               "client_id" => client_id,
               "client_secret" => client_secret,
               "client_secret_expires_at" => 0
             } = json_response(conn, 201)

      assert client_id
      assert client_secret
    end

    test "creates associated identity provider", %{conn: conn} do
      conn =
        post(conn, Routes.dynamic_registration_path(conn, :register_client), %{
          redirect_uris: ["https://test.uri"]
        })

      assert %{
               "client_id" => client_id
             } = json_response(conn, 201)

      assert %ClientIdentityProvider{identity_provider_id: identity_provider_id} =
               BorutaIdentity.Repo.get_by(ClientIdentityProvider, client_id: client_id)

      assert BorutaIdentity.Repo.get!(IdentityProvider, identity_provider_id)
    end
  end
end
