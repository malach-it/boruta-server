defmodule BorutaWeb.Oauth.AuthenticableRequestParamTest do
  use BorutaWeb.ConnCase

  import BorutaWeb.Factory

  alias BorutaIdentityWeb.Authenticable
  alias BorutaIdentityWeb.Token

  test "stateful provider keeps the signed request in the session", %{conn: conn} do
    endpoint_config = Application.fetch_env!(:boruta_identity, BorutaIdentityWeb.Endpoint)

    Application.put_env(
      :boruta_identity,
      BorutaIdentityWeb.Endpoint,
      endpoint_config
      |> Keyword.put(:session_cookie_key, "_boruta_identity_test_key")
      |> Keyword.put(:session_cookie_signing_salt, "test_salt")
    )

    on_exit(fn ->
      Application.put_env(:boruta_identity, BorutaIdentityWeb.Endpoint, endpoint_config)
    end)

    client = insert(:client)

    identity_provider =
      BorutaWeb.IdentityFactory.insert(:identity_provider, request_mode: "stateful")

    BorutaWeb.IdentityFactory.insert(:client_identity_provider,
      client_id: client.id,
      identity_provider: identity_provider
    )

    authorize_path =
      Routes.authorize_path(conn, :authorize, %{
        response_type: "code",
        client_id: client.id,
        redirect_uri: List.first(client.redirect_uris),
        scope: "openid"
      })

    conn = get(conn, authorize_path)

    stored_request = get_session(conn, :authorization_request)

    assert URI.parse(redirected_to(conn)).query == nil
    assert %{"id" => request, "jwt" => jwt} = stored_request

    assert {:ok, %{"client_id" => client_id, "scope" => "openid"}} =
             Token.verify(jwt, Token.application_signer())

    assert client_id == client.id
    assert {:error, _} = Token.verify(request, Token.application_signer())

    identity_conn =
      build_conn()
      |> init_test_session(authorization_request: stored_request)
      |> Map.put(:query_params, %{})

    assert Authenticable.client_id_from_request(identity_conn) == client.id
    assert Authenticable.scope_from_request(identity_conn) == "openid"
    assert Authenticable.user_return_to_from_request(identity_conn) =~ "/oauth/authorize"

    identity_page =
      build_conn()
      |> init_test_session(authorization_request: stored_request)
      |> get("/accounts/users/log_in")

    assert response(identity_page, 200) =~ "/users/log_in"
    assert response(identity_page, 200) =~
             IdentityRoutes.user_session_path(identity_page, :create, request: request)

    assert Authenticable.client_id_from_request(%{
             identity_conn
             | query_params: %{"request" => "different"}
           }) == nil

    invalid_session_conn =
      build_conn()
      |> init_test_session(authorization_request: %{"id" => request, "jwt" => "invalid"})
      |> Map.put(:query_params, %{})

    assert Authenticable.client_id_from_request(invalid_session_conn) == nil

    resumed_conn =
      build_conn()
      |> init_test_session(authorization_request: stored_request)
      |> get(authorize_path)

    assert URI.parse(redirected_to(resumed_conn)).query == nil
    assert get_session(resumed_conn, :authorization_request)["id"] == request
  end

  test "stateless provider keeps the signed request parameter", %{conn: conn} do
    client = insert(:client)

    identity_provider =
      BorutaWeb.IdentityFactory.insert(:identity_provider, request_mode: "stateless")

    BorutaWeb.IdentityFactory.insert(:client_identity_provider,
      client_id: client.id,
      identity_provider: identity_provider
    )

    conn =
      conn
      |> init_test_session(authorization_request: %{"id" => "old", "jwt" => "old"})
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: List.first(client.redirect_uris)
        })
      )

    request =
      redirected_to(conn)
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()
      |> Map.fetch!("request")

    assert {:ok, %{"client_id" => client_id}} = Token.verify(request, Token.application_signer())
    assert client_id == client.id
    assert get_session(conn, :authorization_request) == nil
  end

  test "request_param drops prompt and max_age without rewriting other parameter values", %{
    conn: conn
  } do
    redirect_uri = "http://redirect.uri"
    client = insert(:client, redirect_uris: [redirect_uri])
    scope = insert(:scope)

    request =
      conn
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: scope.name,
          prompt: "login",
          max_age: "10",
          state: "keep prompt=none and max_age=10"
        })
      )
      |> Authenticable.request_param()

    assert {:ok, %{"user_return_to" => user_return_to}} =
             Token.verify(request, Token.application_signer())

    uri = URI.parse(user_return_to)
    query = URI.decode_query(uri.query)

    refute Map.has_key?(query, "prompt")
    refute Map.has_key?(query, "max_age")
    assert query["state"] == "keep prompt=none and max_age=10"
  end
end
