defmodule BorutaGateway.BrowserSessionTest do
  use ExUnit.Case, async: false
  use BorutaGateway.DataCase
  alias BorutaGateway.Authorization.OauthSession, as: BrowserSession

  setup do
    previous = Application.get_env(:boruta_gateway, :session_secret_key_base)
    Application.put_env(:boruta_gateway, :session_secret_key_base, String.duplicate("s", 64))

    on_exit(fn ->
      if previous,
        do: Application.put_env(:boruta_gateway, :session_secret_key_base, previous),
        else: Application.delete_env(:boruta_gateway, :session_secret_key_base)
    end)

    :ok
  end

  test "session cookies are encrypted and reject tampering" do
    session = %{token: "private-token", origin: "https://example.com"}
    value = BrowserSession.encode_session(session)
    refute value =~ "private-token"
    assert BrowserSession.decode_session(value) == session
    assert BrowserSession.decode_session(value <> "corrupted") == nil
    assert BrowserSession.decode_session(nil) == nil
  end

  test "callback rejects POST requests" do
    id =
      BrowserSession.encode_session(%{
        state: "expected",
        origin: "https://example.com",
        target: "/private"
      })

    header =
      "POST /__implicit/callback HTTP/1.1\r\nHost: example.com\r\nCookie: boruta_gateway_session=#{id}\r\n\r\n"

    assert {:browser_response, response} =
             BrowserSession.prepare(header, "https", "access_token=bad&state=wrong")

    assert response =~ "405 Method Not Allowed"
    assert %{state: "expected"} = BrowserSession.decode_session(id)
  end

  test "ordinary requests pass through callback handling" do
    assert :ok = BrowserSession.prepare("GET /private HTTP/1.1\r\nHost: example.com\r\n", "https")
  end

  test "unprotected endpoints do not initiate login" do
    assert {:ok, nil} =
             BorutaGateway.Authorization.authorize(
               "GET / HTTP/1.1\r\nAccept: text/html\r\n",
               "GET",
               %BorutaGateway.Upstreams.Upstream{authorize: false},
               "https"
             )
  end

  for {flow, wallet_uri} <- [
        {"implicit", nil},
        {"implicit", "https://wallet.example.com/authorize"},
        {"verifiable_presentation", nil},
        {"verifiable_presentation", "https://wallet.example.com/authorize"}
      ] do
    @flow flow
    @wallet_uri wallet_uri
    @redirect_uri if flow == "verifiable_presentation" && wallet_uri,
                    do: wallet_uri,
                    else: "https://example.com/__implicit/callback"
    test "#{flow} browser login with wallet #{inspect(wallet_uri)} preserves its flow, query parameters and secure session cookie" do
      alias Boruta.Ecto.{Admin, ClientStore}
      previous = ClientStore.get_public()
      {:ok, client} = Admin.create_client(%{access_token_ttl: 3600})
      ClientStore.put_public(Boruta.ClientsAdapter.get_client(client.id))

      on_exit(fn ->
        case previous do
          {:ok, client} -> ClientStore.put_public(client)
          _ -> ClientStore.invalidate_public()
        end
      end)

      upstream = %BorutaGateway.Upstreams.Upstream{
        authorize: true,
        authorization_type: "oauth_session",
        oauth_session_flow: @flow,
        oauth_session_wallet_uri: @wallet_uri,
        required_scopes: %{}
      }

      header = "GET /private?view=full HTTP/1.1\r\nHost: example.com\r\nAccept: text/html\r\n\r\n"

      assert {:browser_response, response} =
               BorutaGateway.Authorization.authorize(header, "GET", upstream, "https")

      assert response =~ "302 Found"
      response_type = if @flow == "implicit", do: "token", else: "vp_token"
      assert response =~ "response_type=#{response_type}"
      assert response =~ "client_metadata=" == (@flow == "verifiable_presentation")
      assert response =~ "; Secure"
      [_, id] = Regex.run(~r/boruta_gateway_session=([^;]+)/, response)

      assert %{target: "/private?view=full", state: state} =
               BrowserSession.decode_session(id)

      assert BrowserSession.decode_session(id).oauth_session_flow == @flow
      assert BrowserSession.decode_session(id).oauth_session_wallet_uri == @wallet_uri

      assert BrowserSession.decode_session(id).relying_party_redirect_uri ==
               "https://example.com/__implicit/callback"

      assert BrowserSession.decode_session(id).client_id == client.id

      [_, location] = Regex.run(~r/Location: ([^\r\n]+)/, response)
      query = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      refute Map.has_key?(query, "relying_party_session")
      refute Map.has_key?(query, "relying_party_redirect_uri")
      refute location =~ id

      assert response =~ "state=" <> state

      redirect_uri = @redirect_uri

      assert response =~ URI.encode_query(%{redirect_uri: redirect_uri})
      public = Boruta.ClientsAdapter.get_client(client.id)

      {:ok, token} =
        Boruta.AccessTokensAdapter.create(%{client: public, scope: "", sub: "user"}, [])

      callback_header =
        "GET /__implicit/callback HTTP/1.1\r\nHost: example.com\r\nCookie: boruta_gateway_session=#{id}\r\n\r\n"

      assert {:browser_response, page} = BrowserSession.prepare(callback_header, "https")
      [_, script] = Regex.run(~r/<script nonce="[^"]+">(.*?)<\/script>/s, page)
      fragment = URI.encode_query(%{access_token: token.value, state: state, expires_in: 600})
      result = run_callback(script, fragment)
      assert result["redirect"] == "https://example.com/private?view=full"
      assert result["cookie"] =~ "Max-Age=600"
      assert result["cookie"] =~ "; Secure"
      refute result["cookie"] =~ "HttpOnly"

      invalid =
        run_callback(script, URI.encode_query(%{access_token: token.value, state: "wrong"}))

      refute invalid["cookie"]
      assert invalid["redirect"] == "https://example.com/private?view=full"
      access_cookie = result["cookie"] |> String.split(";") |> hd()
      session = id <> "; " <> access_cookie

      request =
        "GET /private HTTP/1.1\r\nHost: example.com\r\nCookie: boruta_gateway_session=#{session}\r\n\r\n"

      assert {:ok, authorized} =
               BorutaGateway.Authorization.authorize(request, "GET", upstream, "https")

      assert authorized.value == token.value

      revoke_header =
        "POST /__implicit/revoke HTTP/1.1\r\nHost: example.com\r\nOrigin: https://example.com\r\nCookie: boruta_gateway_session=#{session}\r\n\r\n"

      assert {:browser_response, revoked} = BrowserSession.prepare(revoke_header, "https")
      assert revoked =~ "302 Found"
      assert revoked =~ "response_type=#{response_type}"
      assert revoked =~ URI.encode_query(%{redirect_uri: redirect_uri})
      [_, pending] = Regex.run(~r/boruta_gateway_session=([^;]+)/, revoked)
      assert %{target: "/private?view=full", state: _} = BrowserSession.decode_session(pending)
      assert BrowserSession.decode_session(pending).oauth_session_flow == @flow
      assert BrowserSession.decode_session(pending).oauth_session_wallet_uri == @wallet_uri
      refute Map.has_key?(BrowserSession.decode_session(pending), :token)
      assert revoked =~ "; Secure"
      assert {:browser_response, repeated} = BrowserSession.prepare(revoke_header, "https")
      assert repeated =~ "302 Found"

      assert {:browser_response, redirect} =
               BorutaGateway.Authorization.authorize(request, "GET", upstream, "https")

      assert redirect =~ "response_type=#{response_type}"
    end
  end

  test "revocation restarts login when the origin or cookie is missing" do
    alias Boruta.Ecto.{Admin, ClientStore}
    previous = ClientStore.get_public()
    {:ok, client} = Admin.create_client(%{access_token_ttl: 3600})
    ClientStore.put_public(Boruta.ClientsAdapter.get_client(client.id))

    on_exit(fn ->
      case previous do
        {:ok, client} -> ClientStore.put_public(client)
        _ -> ClientStore.invalidate_public()
      end
    end)

    header = "POST /__implicit/revoke HTTP/1.1\r\nHost: example.com\r\n"
    assert {:browser_response, denied} = BrowserSession.prepare(header, "https")
    assert denied =~ "302 Found"
    assert denied =~ "response_type=vp_token"

    assert {:browser_response, empty} =
             BrowserSession.prepare(header <> "Origin: https://example.com\r\n", "https")

    assert empty =~ "302 Found"
    assert empty =~ "response_type=vp_token"

    assert {:browser_response, method} =
             BrowserSession.prepare(
               "GET /__implicit/revoke HTTP/1.1\r\nHost: example.com\r\n",
               "https"
             )

    assert method =~ "405 Method Not Allowed"
    assert method =~ "Allow: POST"
  end

  test "expired and foreign-key cookies are rejected" do
    expired =
      Plug.Crypto.encrypt(
        String.duplicate("s", 64),
        "boruta gateway browser session v1",
        %{token: "expired"},
        signed_at: System.system_time(:second) - 3601
      )

    assert BrowserSession.decode_session(expired) == nil

    foreign =
      Plug.Crypto.encrypt(String.duplicate("x", 64), "boruta gateway browser session v1", %{
        token: "foreign"
      })

    assert BrowserSession.decode_session(foreign) == nil
  end

  test "forwarding removes only the gateway session cookie" do
    header = "GET / HTTP/1.1\r\nCookie: app=one; boruta_gateway_session=secret; other=two\r\n\r\n"
    result = BrowserSession.strip_cookie(header)
    refute result =~ "secret"
    assert result =~ "app=one"
    assert result =~ "other=two"
  end

  defp run_callback(script, fragment) do
    runner = """
    const vm = require('node:vm');
    const output = {};
    const document = {documentElement: {}};
    Object.defineProperty(document, 'cookie', {set(value) {output.cookie = value;}});
    vm.runInNewContext(process.argv[1], {
      URL, URLSearchParams, btoa,
      document,
      history: {replaceState() {output.cleared = true;}},
      location: {hash: '#' + process.argv[2], pathname: '/__implicit/callback', origin: 'https://example.com', replace(value) {output.redirect = value;}}
    });
    process.stdout.write(JSON.stringify(output));
    """

    {output, 0} = System.cmd("node", ["-e", runner, script, fragment])
    Jason.decode!(output)
  end
end
