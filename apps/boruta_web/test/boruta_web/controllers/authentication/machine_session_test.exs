defmodule BorutaWeb.Oauth.MachineSessionTest do
  use BorutaWeb.ConnCase

  import BorutaWeb.Factory

  alias Boruta.ClientsAdapter
  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.ClientStore
  alias Boruta.Oauth
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid.VerifiablePresentations
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.Machine
  alias BorutaIdentity.Accounts.Sessions
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo
  alias BorutaIdentityWeb.MachineSession

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

  test "a normal authorization clears an unbound machine session before login", %{conn: conn} do
    machine =
      BorutaWeb.IdentityFactory.insert(:user,
        account_type: "machine",
        uid: "did:key:machine-session"
      )

    {:ok, _machine, session_token} = Sessions.create_user_session(machine)
    client = insert(:client)
    identity_provider = BorutaWeb.IdentityFactory.insert(:identity_provider)

    BorutaWeb.IdentityFactory.insert(:client_identity_provider,
      client_id: client.id,
      identity_provider: identity_provider
    )

    authorization =
      conn
      |> init_test_session(
        user_token: session_token,
        machine_authorization: %{
          code: "other-code",
          client_id: "did:jwk:other",
          user_id: machine.id
        }
      )
      |> get(
        Routes.authorize_path(conn, :authorize, %{
          response_type: "code",
          client_id: client.id,
          redirect_uri: List.first(client.redirect_uris)
        })
      )

    assert redirected_to(authorization) =~ "/users/log_in"
    assert get_session(authorization, :user_token) == nil
    assert get_session(authorization, :machine_authorization) == nil
    assert Accounts.get_user_by_session_token(session_token) == nil

    login =
      authorization
      |> recycle()
      |> Phoenix.ConnTest.dispatch(BorutaIdentityWeb.Endpoint, :get, redirected_to(authorization))

    assert html_response(login, 200) =~ "Log in"
  end

  test "OID4VP machine consent follows the public client's identity provider", %{conn: conn} do
    public_client = ClientsAdapter.public!()
    redirect_uri = "https://redirect.uri"

    {:ok, _client} =
      public_client.id
      |> Admin.get_client!()
      |> Admin.update_client(%{
        confidential: false,
        redirect_uris: [redirect_uri],
        supported_grant_types: Oauth.Client.grant_types()
      })

    ClientStore.invalidate_public()

    identity_provider = BorutaWeb.IdentityFactory.insert(:identity_provider, consentable: true)

    {:ok, _association} =
      IdentityProviders.upsert_client_identity_provider(public_client.id, identity_provider.id)

    on_exit(fn ->
      BorutaIdentity.Cache.delete(
        {IdentityProviders, :identity_provider_by_client_id, public_client.id}
      )
    end)

    scope = insert(:scope, public: true)
    private_key = build(:client).private_key

    {_, jwk} =
      private_key
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()
      |> JOSE.JWK.to_map()

    did = "did:jwk:" <> (Jason.encode!(jwk) |> Base.url_encode64(padding: false))
    signer = Joken.Signer.create("RS256", %{"pem" => private_key}, %{"jwk" => jwk, "kid" => did})
    {:ok, id_token, _claims} = VerifiablePresentations.Token.generate_and_sign(%{}, signer)

    code =
      insert(:token,
        type: "code",
        client: Admin.get_client!(public_client.id),
        sub: did,
        public_client_id: did,
        response_type: "id_token vp_token",
        scope: scope.name,
        redirect_uri: redirect_uri
      )

    direct_post =
      conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> post("/openid/direct_post/#{code.id}", "id_token=#{id_token}")

    redirect_uri = direct_post |> redirected_to() |> URI.parse()
    assert redirect_uri.path == "/oauth/authorize"
    return_to = redirect_uri.path <> "?" <> redirect_uri.query
    assert URI.decode_query(redirect_uri.query)["response_type"] == "vp_token"

    {:ok, machine} = Machine.domain_user!(%ResourceOwner{sub: id_token}, Backend.default!())

    assert machine.uid =~ "did:key:"
    session_token = get_session(direct_post, :user_token)
    assert is_binary(session_token)
    assert Accounts.get_user_by_session_token(session_token).id == machine.id

    same_device_authorization = direct_post |> recycle() |> get(return_to)
    assert same_device_authorization.assigns.current_user.id == machine.id
    assert redirected_to(same_device_authorization) =~ "/users/consent"

    assert MachineSession.from_session_authorize(%{
             same_device_authorization
             | query_params: Map.put(same_device_authorization.query_params, "code", "wrong-code")
           }) == nil

    assert MachineSession.from_session_authorize(%{
             same_device_authorization
             | query_params:
                 Map.put(
                   same_device_authorization.query_params,
                   "client_id",
                   "did:key:another-client"
                 )
           }) == nil

    refute Accounts.consented?(machine, did, [scope.name])
    refute Accounts.consented?(nil, did, [scope.name])

    without_session = get(conn, return_to)
    assert without_session.assigns.current_user == nil
    assert redirected_to(without_session) =~ "/users/consent"

    {:ok, request, _claims} =
      Joken.encode_and_sign(
        %{"client_id" => did, "scope" => scope.name, "user_return_to" => return_to},
        BorutaIdentityWeb.Token.application_signer()
      )

    consent_path = IdentityRoutes.user_consent_path(conn, :index, %{request: request})

    no_session_consent =
      conn
      |> Phoenix.ConnTest.dispatch(BorutaIdentityWeb.Endpoint, :get, consent_path)

    assert redirected_to(no_session_consent) =~ "/users/log_in"

    wrong_code_return_to =
      return_to
      |> URI.parse()
      |> then(fn uri ->
        %{
          uri
          | query:
              uri.query
              |> URI.decode_query()
              |> Map.put("code", "wrong-code")
              |> URI.encode_query()
        }
      end)
      |> URI.to_string()

    {:ok, wrong_code_request, _claims} =
      Joken.encode_and_sign(
        %{"client_id" => did, "scope" => scope.name, "user_return_to" => wrong_code_return_to},
        BorutaIdentityWeb.Token.application_signer()
      )

    wrong_code_consent_path =
      IdentityRoutes.user_consent_path(conn, :index, %{request: wrong_code_request})

    rejected_consent =
      same_device_authorization
      |> recycle()
      |> Phoenix.ConnTest.dispatch(BorutaIdentityWeb.Endpoint, :get, wrong_code_consent_path)

    assert response(rejected_consent, 403) == "Invalid machine authorization session."

    page =
      same_device_authorization
      |> recycle()
      |> Phoenix.ConnTest.dispatch(BorutaIdentityWeb.Endpoint, :get, consent_path)

    html = html_response(page, 200)
    assert html =~ "Consent"
    assert html =~ did
    assert page.assigns.current_user.id == machine.id

    [_, csrf] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html)

    response =
      page
      |> recycle()
      |> Phoenix.ConnTest.dispatch(BorutaIdentityWeb.Endpoint, :post, consent_path, %{
        "_csrf_token" => csrf,
        "scopes" => [scope.name]
      })

    assert redirected_to(response) == return_to
    assert Accounts.consented?(machine, did, [scope.name])
    refute Accounts.consented?(machine, "did:key:another-client", [scope.name])

    resumed =
      response
      |> recycle()
      |> Phoenix.ConnTest.dispatch(BorutaWeb.Endpoint, :get, return_to)

    assert redirected_to(resumed) =~ "request="
    refute String.starts_with?(redirected_to(resumed), "/users/")

    Repo.get_by!(Consent, user_id: machine.id, client_id: did) |> Repo.delete!()

    {:ok, _identity_provider} =
      IdentityProviders.update_identity_provider(identity_provider, %{consentable: false})

    assert Accounts.consented?(machine, did, [scope.name])
    assert Accounts.consented?(nil, did, [scope.name])

    without_consent = direct_post |> recycle() |> get(return_to)
    assert redirected_to(without_consent) =~ "request="
    refute String.starts_with?(redirected_to(without_consent), "/users/")

    Enum.reduce(["id_token", "code"], direct_post, fn response_type, previous_response ->
      siopv2_start =
        previous_response
        |> recycle()
        |> get(
          Routes.authorize_path(conn, :authorize, %{
            response_type: response_type,
            client_id: did,
            redirect_uri: "https://redirect.uri",
            client_metadata: "{}",
            scope: "openid",
            nonce: "nonce"
          })
        )

      deeplink_params =
        siopv2_start |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert deeplink_params["redirect_uri"] =~ "/openid/direct_post/"
      refute redirected_to(siopv2_start) =~ "/users/consent"
      assert get_session(siopv2_start, :user_token) == nil

      siopv2_start
    end)

    assert Accounts.get_user_by_session_token(session_token) == nil
  end
end
