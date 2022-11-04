defmodule BorutaWeb.Integration.OpenidConnectTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable

  alias Boruta.Ecto

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
      conn = get(conn, Routes.openid_path(conn, :jwks_index))

      assert json_response(conn, 200) == %{"keys" => []}
    end

    test "returns all clients keys", %{conn: conn} do
      %Ecto.Client{id: client_id} = insert(:client)

      conn = get(conn, Routes.openid_path(conn, :jwks_index))

      assert %{
               "keys" => [%{"kid" => ^client_id, "kty" => "RSA"}]
             } = json_response(conn, 200)
    end
  end

  describe "discovery 1.0" do
    test "returns required keys", %{conn: conn} do
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
                 "code id_token token"
               ],
               "response_modes_supported" => ["query", "fragment"],
               "subject_types_supported" => ["public"],
               "token_endpoint" => "boruta/oauth/token",
               "userinfo_endpoint" => "boruta/oauth/userinfo"
             }
    end
  end

  describe "dynamic registration" do
    test "returns an error when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.openid_path(conn, :register_client))

      assert json_response(conn, 400) == %{
               "error" => "invalid_redirect_uri",
               "error_description" => "redirect_uris : can't be blank"
             }
    end

    test "registers client", %{conn: conn} do
      conn =
        post(conn, Routes.openid_path(conn, :register_client), %{
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
  end
end
