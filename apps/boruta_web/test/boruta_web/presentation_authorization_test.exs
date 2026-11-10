defmodule BorutaWeb.PresentationAuthorizationTest do
  use BorutaWeb.ConnCase
  import BorutaWeb.Factory
  alias BorutaWeb.PresentationAuthorization, as: Presentation

  setup %{conn: conn} = tags do
    previous = Application.get_env(:boruta_gateway, :session_secret_key_base)
    Application.put_env(:boruta_gateway, :session_secret_key_base, String.duplicate("g", 64))

    on_exit(fn ->
      if previous,
        do: Application.put_env(:boruta_gateway, :session_secret_key_base, previous),
        else: Application.delete_env(:boruta_gateway, :session_secret_key_base)
    end)

    wallet_uri = "https://wallet.example/authorize"
    relying_party_uri = "https://gateway.example/__implicit/callback"
    client = insert(:client, redirect_uris: [relying_party_uri, wallet_uri])
    redirect_uri = if tags[:wallet], do: wallet_uri, else: relying_party_uri

    code =
      insert(:token,
        client: client,
        type: "code",
        response_type: "vp_token token",
        sub: "did:key:presenter",
        scope: "",
        state: "gateway-state",
        redirect_uri: redirect_uri
      )

    token = Boruta.CodesAdapter.get_by(value: code.value)
    conn = %{conn | secret_key_base: String.duplicate("p", 64), query_params: %{}}
    response = %{client: token.client, code: token, redirect_uri: code.redirect_uri}
    bound = Presentation.bind(conn, response)
    cookie = bound.resp_cookies[Presentation.cookie_name(code.value)]
    browser = Plug.Test.put_req_cookie(conn, Presentation.cookie_name(code.value), cookie.value)
    %{conn: conn, browser: browser, cookie: cookie, code: code, response: response}
  end

  @tag :wallet
  test "recovers the relying party callback from the encrypted gateway cookie", ctx do
    conn = Plug.Test.put_req_cookie(ctx.conn, "boruta_gateway_session", gateway_session(ctx))
    {browser, params} = presentation_context(conn, ctx)
    assert params["redirect_uri"] == "https://gateway.example/__implicit/callback"
    assert ctx.code.redirect_uri == "https://wallet.example/authorize"
    refute Map.has_key?(params, "relying_party_session")

    # Subsequent SSE requests only need the issuer's presentation cookie.
    refute Map.has_key?(fetch_cookies(browser).cookies, "boruta_gateway_session")
    assert {:ok, url} = Presentation.complete(ctx.conn, ctx.code.value, params)
    uri = URI.parse(url)
    assert uri.host == "gateway.example"
    assert uri.path == "/__implicit/callback"
    fragment = URI.decode_query(uri.fragment)
    assert fragment["state"] == ctx.code.state

    assert {:ok, token} =
             Boruta.Oauth.Authorization.AccessToken.authorize(value: fragment["access_token"])

    assert token.client.id == ctx.code.client_id
    assert token.sub == ctx.code.sub
    assert {:error, _} = Presentation.complete(ctx.conn, ctx.code.value, params)
  end

  @tag :wallet
  test "ignores query session values and uses the wallet redirect when the cookie is absent",
       ctx do
    conn = %{
      ctx.conn
      | query_params: %{
          "relying_party_session" => gateway_session(ctx),
          "relying_party_redirect_uri" => "https://attacker.example/callback"
        }
    }

    {_browser, params} = presentation_context(conn, ctx)
    assert params["redirect_uri"] == ctx.code.redirect_uri
    refute Map.has_key?(params, "relying_party_session")
    refute Map.has_key?(params, "relying_party_redirect_uri")
    assert {:ok, url} = Presentation.complete(ctx.conn, ctx.code.value, params)
    assert URI.parse(url).host == "wallet.example"
  end

  @tag :wallet
  test "query parameters cannot override a valid gateway cookie", ctx do
    conn = %{
      ctx.conn
      | query_params: %{
          "relying_party_session" => gateway_session(ctx, %{state: "wrong"}),
          "redirect_uri" => "https://attacker.example/callback"
        }
    }

    conn = Plug.Test.put_req_cookie(conn, "boruta_gateway_session", gateway_session(ctx))
    {_browser, params} = presentation_context(conn, ctx)
    assert params["redirect_uri"] == "https://gateway.example/__implicit/callback"
  end

  @tag :wallet
  test "an unregistered redirect in an authentic cookie cannot receive an access token", ctx do
    value =
      gateway_session(ctx, %{relying_party_redirect_uri: "https://unregistered.example/callback"})

    conn = Plug.Test.put_req_cookie(ctx.conn, "boruta_gateway_session", value)
    {_browser, params} = presentation_context(conn, ctx)
    assert params["redirect_uri"] == "https://unregistered.example/callback"
    assert {:error, _} = Presentation.complete(ctx.conn, ctx.code.value, params)
    assert BorutaAuth.Repo.get!(Boruta.Ecto.Token, ctx.code.id).revoked_at
  end

  @tag :wallet
  test "an authentic cookie can select another registered redirect independently of its origin",
       ctx do
    value = gateway_session(ctx, %{relying_party_redirect_uri: ctx.code.redirect_uri})
    conn = Plug.Test.put_req_cookie(ctx.conn, "boruta_gateway_session", value)
    {_browser, params} = presentation_context(conn, ctx)
    assert params["redirect_uri"] == "https://wallet.example/authorize"
    assert {:ok, url} = Presentation.complete(ctx.conn, ctx.code.value, params)
    assert URI.parse(url).host == "wallet.example"
  end

  @tag :wallet
  test "rejects tampered and mismatched relying party sessions", ctx do
    expired =
      Plug.Crypto.encrypt(
        String.duplicate("g", 64),
        "boruta gateway browser session v1",
        BorutaAuth.GatewaySession.decode(gateway_session(ctx)),
        signed_at: System.system_time(:second) - 3601
      )

    for value <- [
          expired,
          gateway_session(ctx) <> "bad",
          gateway_session(ctx, %{state: "other-state"}),
          gateway_session(ctx, %{client_id: "other-client"}),
          gateway_session(ctx, %{oauth_session_flow: "implicit"}),
          gateway_session(ctx, %{relying_party_redirect_uri: nil}),
          gateway_session(ctx, %{origin: nil}),
          BorutaAuth.GatewaySession.encode(%{}),
          BorutaAuth.GatewaySession.encode("not a session"),
          Plug.Crypto.encrypt(String.duplicate("x", 64), "boruta gateway browser session v1", %{})
        ] do
      conn = Plug.Test.put_req_cookie(ctx.conn, "boruta_gateway_session", value)
      bound = Presentation.bind(conn, ctx.response)
      refute Map.has_key?(bound.resp_cookies, Presentation.cookie_name(ctx.code.value))
      assert :error = Presentation.context(ctx.conn, ctx.code.value)

      assert response(
               BorutaWeb.Oauth.AuthorizeController.authenticated?(ctx.conn, %{
                 "code" => ctx.code.value
               }),
               401
             )

      refute BorutaAuth.Repo.get!(Boruta.Ecto.Token, ctx.code.id).revoked_at
    end
  end

  defp presentation_context(conn, ctx) do
    bound = Presentation.bind(conn, ctx.response)
    name = Presentation.cookie_name(ctx.code.value)
    browser = Plug.Test.put_req_cookie(ctx.conn, name, bound.resp_cookies[name].value)
    assert {:ok, params} = Presentation.context(browser, ctx.code.value)
    {browser, params}
  end

  defp gateway_session(ctx, overrides \\ %{}) do
    %{
      state: ctx.code.state,
      client_id: ctx.code.client_id,
      origin: "https://gateway.example",
      relying_party_redirect_uri: "https://gateway.example/__implicit/callback",
      oauth_session_flow: "verifiable_presentation"
    }
    |> Map.merge(overrides)
    |> BorutaAuth.GatewaySession.encode()
  end

  @tag :cookie_cleanup
  test "binding deletes previous presentation cookies and keeps unrelated cookies", ctx do
    old_name = Presentation.cookie_name("previous-code")

    conn =
      ctx.conn
      |> Plug.Test.put_req_cookie(old_name, "previous")
      |> Plug.Test.put_req_cookie("unrelated", "keep")
      |> Presentation.bind(ctx.response)

    assert conn.resp_cookies[old_name].max_age == 0
    assert conn.resp_cookies[old_name].path == "/"
    refute Map.has_key?(conn.resp_cookies, "unrelated")
    current = conn.resp_cookies[Presentation.cookie_name(ctx.code.value)]
    assert current.max_age == 300
    assert current.path == "/"
    assert current.http_only
  end

  test "cookie is encrypted, HttpOnly and bound to the presentation code", ctx do
    assert ctx.cookie.http_only
    assert ctx.cookie.secure
    assert ctx.cookie.same_site == "Lax"
    refute ctx.cookie.value =~ ctx.code.value
    assert {:ok, params} = Presentation.context(ctx.browser, ctx.code.value)
    assert params["state"] == "gateway-state"
    assert params["response_type"] == "token"
    assert params["redirect_uri"] == ctx.code.redirect_uri
    assert :error = Presentation.context(ctx.conn, ctx.code.value)

    tampered =
      Plug.Test.put_req_cookie(
        ctx.conn,
        Presentation.cookie_name(ctx.code.value),
        ctx.cookie.value <> "bad"
      )

    assert :error = Presentation.context(tampered, ctx.code.value)
  end

  test "completion returns the implicit callback with the verified subject and is single-use",
       ctx do
    assert {:ok, params} = Presentation.context(ctx.browser, ctx.code.value)
    assert {:ok, url} = Presentation.complete(ctx.conn, ctx.code.value, params)
    uri = URI.parse(url)
    assert uri.host == "gateway.example"
    assert uri.path == "/__implicit/callback"
    fragment = URI.decode_query(uri.fragment)
    assert fragment["state"] == "gateway-state"
    assert fragment["token_type"] == "bearer"

    assert {:ok, token} =
             Boruta.Oauth.Authorization.AccessToken.authorize(value: fragment["access_token"])

    assert token.sub == "did:key:presenter"
    assert token.client.id == ctx.code.client_id
    assert {:error, _} = Presentation.complete(ctx.conn, ctx.code.value, params)
  end

  test "failed token issuance leaves the presentation code revoked", ctx do
    {:ok, params} = Presentation.context(ctx.browser, ctx.code.value)
    params = Map.put(params, "redirect_uri", "https://unregistered.example/callback")
    assert {:error, _} = Presentation.complete(ctx.conn, ctx.code.value, params)
    assert BorutaAuth.Repo.get!(Boruta.Ecto.Token, ctx.code.id).revoked_at

    assert {:error, _} =
             Presentation.complete(
               ctx.conn,
               ctx.code.value,
               Map.put(params, "redirect_uri", ctx.code.redirect_uri)
             )
  end

  test "concurrent completion issues only one access token", ctx do
    {:ok, params} = Presentation.context(ctx.browser, ctx.code.value)
    params = Map.put(params, "redirect_uri", ctx.code.redirect_uri)
    owner = self()

    results =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(BorutaAuth.Repo, owner, self())
          Presentation.complete(ctx.conn, ctx.code.value, params)
        end)
      end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, _}, &1)) == 1
  end

  test "SSE sends the implicit callback instead of the intermediate authorization URL", ctx do
    send(self(), {:authenticated, "https://issuer.example/oauth/authorize?code=intermediate"})

    conn =
      BorutaWeb.Oauth.AuthorizeController.authenticated?(ctx.browser, %{"code" => ctx.code.value})

    assert response(conn, 200) =~
             "event: authenticated\ndata: https://gateway.example/__implicit/callback#"

    BorutaWeb.PresentationServer.cancel_presentation(ctx.code.value)
  end

  test "expired and code-mismatched cookies are rejected", ctx do
    params = %{code: ctx.code.value, params: %{}}

    expired =
      Plug.Crypto.encrypt(
        ctx.conn.secret_key_base,
        "presentation implicit authorization v1",
        params,
        signed_at: System.system_time(:second) - 301
      )

    expired_conn =
      Plug.Test.put_req_cookie(ctx.conn, Presentation.cookie_name(ctx.code.value), expired)

    assert :error = Presentation.context(expired_conn, ctx.code.value)

    other =
      Plug.Test.put_req_cookie(ctx.conn, Presentation.cookie_name("other"), ctx.cookie.value)

    assert :error = Presentation.context(other, "other")
  end

  test "credential offers do not set the presentation cookie", ctx do
    response = Map.update!(ctx.response, :code, &%{&1 | response_type: "pre-authorized_code"})
    assert Presentation.bind(ctx.conn, response).resp_cookies == %{}
  end
end
