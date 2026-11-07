defmodule BorutaWeb.SessionCookieTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  alias BorutaWeb.Oauth.AuthorizeController
  alias BorutaWeb.SessionCookie

  setup do
    conn =
      Plug.Test.conn(:get, "/oauth/authorize?client_id=current")
      |> Map.put(:secret_key_base, BorutaWeb.Endpoint.config(:secret_key_base))
      |> BorutaWeb.Endpoint.put_configured_session([])
      |> fetch_session()
      |> fetch_query_params()
      |> put_session(:user_token, %{"current" => "current-token", "other" => "other-token"})
      |> put_session(:totp_authenticated, %{"current-token" => true, "other-token" => true})
      |> put_session(:webauthn_authenticated, %{"current-token" => true})
      |> put_session(:session_chosen, true)
      |> put_session(:authorization_request, %{
        "id" => "current-request",
        "jwt" => "signed-request"
      })
      |> assign(:request_param, "current-request")

    %{conn: conn}
  end

  test "leaves a fitting session unchanged", %{conn: conn} do
    conn = put_session(conn, :preauthorizations, %{"old-request" => true})
    assert {:ok, cleaned} = SessionCookie.clean_if_oversized(conn, "current", "current-request")
    assert get_session(cleaned) == get_session(conn)
    assert_cookie_fits(send_resp(cleaned, 200, ""))
  end

  test "preauthorization success removes stale entries and keeps concurrent logins", %{conn: conn} do
    conn =
      conn
      |> put_session(:preauthorizations, %{String.duplicate("old-request", 500) => true})
      |> put_session(:totp_authenticated, %{
        "current-token" => true,
        "other-token" => true,
        "orphan" => true
      })
      |> AuthorizeController.preauthorize_success(:preauthorized)

    assert conn.status == 302
    assert get_session(conn, :preauthorizations) == %{"current-request" => true}

    assert get_session(conn, :user_token) == %{
             "current" => "current-token",
             "other" => "other-token"
           }

    assert get_session(conn, :totp_authenticated) == %{
             "current-token" => true,
             "other-token" => true
           }

    assert get_session(conn, :webauthn_authenticated) == %{"current-token" => true}
    assert get_session(conn, :authorization_request)["jwt"] == "signed-request"
    assert_cookie_fits(conn)
  end

  test "prunes orphaned MFA entries when they cause overflow", %{conn: conn} do
    stale = Map.new(1..100, &{"expired-token-#{&1}", true})
    conn = put_session(conn, :webauthn_authenticated, Map.put(stale, "current-token", true))
    assert {:ok, conn} = SessionCookie.clean_if_oversized(conn, "current", "current-request")
    assert get_session(conn, :webauthn_authenticated) == %{"current-token" => true}
    assert get_session(conn, :user_token)["other"] == "other-token"
    assert_cookie_fits(send_resp(conn, 200, ""))
  end

  test "keeps only the current login if concurrent sessions still exceed the limit", %{conn: conn} do
    tokens = Map.new(1..100, &{"client-#{&1}", :crypto.strong_rand_bytes(32)})

    conn =
      conn
      |> put_session(:user_token, Map.put(tokens, "current", "current-token"))
      |> AuthorizeController.preauthorize_success(:preauthorized)

    assert get_session(conn, :user_token) == %{"current" => "current-token"}
    assert get_session(conn, :totp_authenticated) == %{"current-token" => true}
    assert get_session(conn, :webauthn_authenticated) == %{"current-token" => true}
    assert get_session(conn, :preauthorizations) == %{"current-request" => true}
    assert_cookie_fits(conn)
  end

  test "checks size when redirecting to session selection too", %{conn: conn} do
    conn =
      conn
      |> delete_session(:session_chosen)
      |> put_session(:preauthorizations, %{String.duplicate("old", 2000) => true})
      |> AuthorizeController.preauthorize_success(:preauthorized)

    assert conn.status == 302
    assert get_resp_header(conn, "location") |> hd() =~ "/users/choose_session"
    assert get_session(conn, :preauthorizations) == %{}
    assert_cookie_fits(conn)
  end

  test "clears the session and reports an error if the current request alone cannot fit", %{
    conn: conn
  } do
    conn =
      conn
      |> put_session(:authorization_request, %{
        "id" => "current-request",
        "jwt" => String.duplicate("x", 5000)
      })

    assert {:error, cleaned} =
             SessionCookie.clean_if_oversized(conn, "current", "current-request")

    assert get_session(cleaned) == %{}
    assert_cookie_fits(send_resp(cleaned, 200, ""))

    assert_raise BorutaIdentity.Accounts.IdentityProviderError,
                 "Unprocessable request, session is too large.",
                 fn -> AuthorizeController.preauthorize_success(conn, :preauthorized) end
  end

  defp assert_cookie_fits(conn) do
    key = BorutaWeb.Endpoint.session_options()[:key]
    cookie = conn.resp_cookies[key]
    assert cookie
    assert byte_size(Plug.Conn.Cookies.encode(key, cookie)) <= 4096
  end
end
