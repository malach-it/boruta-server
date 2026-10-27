defmodule BorutaWeb.Oauth.ConsentAuthorizationTest do
  use BorutaWeb.ConnCase

  import BorutaIdentity.AccountsFixtures
  import BorutaWeb.Factory

  setup_all do
    identity_config = Application.fetch_env!(:boruta_identity, BorutaIdentityWeb.Endpoint)
    web_config = Application.fetch_env!(:boruta_web, BorutaWeb.Endpoint)

    Application.put_env(
      :boruta_identity,
      BorutaIdentityWeb.Endpoint,
      Keyword.merge(
        identity_config,
        Keyword.take(web_config, [:session_cookie_key, :session_cookie_signing_salt])
      )
    )

    on_exit(fn ->
      Application.put_env(:boruta_identity, BorutaIdentityWeb.Endpoint, identity_config)
    end)
  end

  setup %{conn: conn} do
    user = user_fixture()
    client = insert(:client)
    identity_provider = BorutaWeb.IdentityFactory.insert(:identity_provider, consentable: true)

    BorutaWeb.IdentityFactory.insert(:client_identity_provider,
      client_id: client.id,
      identity_provider: identity_provider
    )

    scope = insert(:scope, public: true)
    redirect_uri = List.first(client.redirect_uris)

    authorize_path =
      Routes.authorize_path(conn, :authorize, %{
        response_type: "code",
        client_id: client.id,
        redirect_uri: redirect_uri,
        scope: scope.name
      })

    %{
      user: user,
      client: client,
      scope: scope,
      redirect_uri: redirect_uri,
      authorize_path: authorize_path
    }
  end

  test "returning to authorize before deciding consent does not issue a code", %{
    conn: conn,
    client: client,
    user: user,
    authorize_path: authorize_path,
    redirect_uri: redirect_uri
  } do
    consent_redirect =
      conn
      |> log_in_for_client(user, client.id)
      |> init_test_session(session_chosen: true)
      |> get(authorize_path)

    assert redirected_to(consent_redirect) =~ IdentityRoutes.user_consent_path(conn, :index)

    resumed = consent_redirect |> recycle() |> get(authorize_path)

    refute URI.parse(redirected_to(resumed)).host == URI.parse(redirect_uri).host
  end

  test "non-consentable provider authorizes without an existing consent", %{conn: conn} do
    user = user_fixture()
    client = insert(:client)
    identity_provider = BorutaWeb.IdentityFactory.insert(:identity_provider, consentable: false)

    BorutaWeb.IdentityFactory.insert(:client_identity_provider,
      client_id: client.id,
      identity_provider: identity_provider
    )

    scope = insert(:scope, public: true)
    redirect_uri = List.first(client.redirect_uris)

    assert BorutaIdentity.Accounts.consented?(user, client.id, [scope.name])

    consent_redirect =
      conn
      |> log_in_for_client(user, client.id)
      |> init_test_session(session_chosen: true)
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: scope.name
        })
      )

    assert redirected_to(consent_redirect) =~ IdentityRoutes.user_consent_path(conn, :index)

    response =
      consent_redirect
      |> recycle()
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: scope.name
        })
      )

    assert URI.parse(redirected_to(response)).host == URI.parse(redirect_uri).host
    assert URI.parse(redirected_to(response)).query =~ "code="
  end

  test "another user's consent cannot authorize this user", %{
    conn: conn,
    user: user,
    client: client,
    scope: scope,
    authorize_path: authorize_path,
    redirect_uri: redirect_uri
  } do
    other_user = user_fixture()

    BorutaWeb.IdentityFactory.insert(:consent,
      user_id: other_user.id,
      client_id: client.id,
      scopes: [scope.name]
    )

    assert_consent_required(conn, user, client.id, authorize_path, redirect_uri)
  end

  test "another client's consent cannot authorize this client", %{
    conn: conn,
    client: client,
    user: user,
    scope: scope,
    authorize_path: authorize_path,
    redirect_uri: redirect_uri
  } do
    other_client = insert(:client)

    BorutaWeb.IdentityFactory.insert(:consent,
      user_id: user.id,
      client_id: other_client.id,
      scopes: [scope.name]
    )

    assert_consent_required(conn, user, client.id, authorize_path, redirect_uri)
  end

  defp assert_consent_required(conn, user, client_id, authorize_path, redirect_uri) do
    response =
      conn
      |> log_in_for_client(user, client_id)
      |> init_test_session(session_chosen: true)
      |> get(authorize_path)

    consent_path = redirected_to(response)
    assert consent_path =~ IdentityRoutes.user_consent_path(conn, :index)

    consent_page =
      Phoenix.ConnTest.dispatch(
        recycle(response),
        BorutaIdentityWeb.Endpoint,
        :get,
        consent_path
      )

    assert html_response(consent_page, 200) =~ "Consent"
    refute URI.parse(consent_path).host == URI.parse(redirect_uri).host
  end
end
