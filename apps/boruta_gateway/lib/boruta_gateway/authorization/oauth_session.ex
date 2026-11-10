defmodule BorutaGateway.Authorization.OauthSession do
  @behaviour BorutaGateway.Authorization
  @moduledoc false

  alias Plug.Conn.Cookies
  @cookie "boruta_gateway_session"
  @access_cookie "boruta_gateway_access_token"
  @callback_path "/__implicit/callback"

  defdelegate encode_session(session), to: BorutaAuth.GatewaySession, as: :encode
  defdelegate decode_session(value), to: BorutaAuth.GatewaySession, as: :decode

  def strip_cookie(header) do
    header
    |> String.split("\r\n")
    |> Enum.map_join("\r\n", &strip_cookie_line/1)
  end

  defp strip_cookie_line(line) do
    case String.split(line, ":", parts: 2) do
      [key, value] ->
        if String.downcase(key) == "cookie" do
          cookies =
            value |> String.split(";") |> Enum.reject(&gateway_cookie?/1) |> Enum.join(";")

          key <> ":" <> cookies
        else
          line
        end

      _ ->
        line
    end
  end

  defp gateway_cookie?(item) do
    Enum.any?([@cookie, @access_cookie], &String.starts_with?(String.trim(item), &1 <> "="))
  end

  def prepare(header, scheme, _body \\ "") do
    [line | _] = String.split(header, "\r\n")

    case String.split(line, " ") do
      ["GET", @callback_path, _] -> callback_page(header, scheme)
      [_, @callback_path, _] -> response(405, [{"Allow", "GET"}])
      ["POST", "/__implicit/revoke", _] -> revoke(header, scheme)
      [_, "/__implicit/revoke", _] -> response(405, [{"Allow", "POST"}])
      _ -> :ok
    end
  end

  def authorize(
        header,
        method,
        %{authorize: true, authorization_type: "oauth_session"} = upstream,
        scheme
      ) do
    origin = origin(header, scheme)
    authorized_header = session_header(header, request_session(header), origin)

    result =
      if authorized_header != header && method not in ["GET", "HEAD", "OPTIONS"] &&
           get_header(header, "origin") != origin do
        revoke(header, scheme)
      else
        BorutaGateway.Authorization.OauthBearer.authorize(
          authorized_header,
          method,
          upstream,
          scheme
        )
      end

    case validate_session_client(result, authorized_header != header, upstream) do
      {:unauthorized, _, _, _} -> begin_login(header, method, upstream, origin, scheme)
      result -> result
    end
  end

  def authorize(header, method, upstream, scheme) do
    BorutaGateway.Authorization.authorize(header, method, upstream, scheme)
  end

  defp session_header(header, %{token: token, origin: origin}, origin) do
    if get_header(header, "authorization"),
      do: header,
      else: header <> "\r\nAuthorization: Bearer " <> token
  end

  defp session_header(header, _session, _origin), do: header

  defp validate_session_client({:ok, token} = result, true, upstream) do
    if token.client.id == Boruta.ClientsAdapter.public!().id,
      do: result,
      else: BorutaGateway.Authorization.Helpers.unauthorized(upstream, nil)
  end

  defp validate_session_client(result, _cookie_authorized?, _upstream), do: result

  defp begin_login(header, method, upstream, origin, scheme, return_to \\ nil) do
    [_, request_target | _] = String.split(header, " ", parts: 3)
    target = return_to || request_target

    if origin && String.starts_with?(target, "/") && !String.starts_with?(target, "//") &&
         upstream.oauth_session_flow in ["implicit", "verifiable_presentation"] do
      client = Boruta.ClientsAdapter.public!()
      state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      scopes =
        Map.get(upstream.required_scopes, method, []) ++
          Map.get(upstream.required_scopes, "*", [])

      id =
        encode_session(%{
          state: state,
          target: target,
          origin: origin,
          client_id: client.id,
          relying_party_redirect_uri: origin <> @callback_path,
          oauth_session_flow: upstream.oauth_session_flow,
          oauth_session_wallet_uri: upstream.oauth_session_wallet_uri,
          scope: Enum.join(scopes, " ")
        })

      params =
        %{
          client_id: client.id,
          scope: Enum.join(scopes, " "),
          state: state
        }

      params =
        case upstream.oauth_session_flow do
          "implicit" ->
            Map.merge(params, %{
              response_type: "token",
              redirect_uri: origin <> @callback_path
            })

          "verifiable_presentation" ->
            Map.merge(params, %{
              response_type: "vp_token",
              client_metadata: "{}",
              redirect_uri: upstream.oauth_session_wallet_uri || origin <> @callback_path
            })
        end

      query = URI.encode_query(params)

      url =
        Boruta.Config.issuer()
        |> URI.parse()
        |> Map.put(:path, "/oauth/authorize")
        |> Map.put(:query, query)
        |> URI.to_string()

      response(302, [
        {"Location", url},
        {"Set-Cookie", session_cookie(id, scheme)},
        {"Set-Cookie",
         @access_cookie <>
           "=; Path=/; SameSite=Lax; Max-Age=0" <> if(scheme == "https", do: "; Secure", else: "")}
      ])
    else
      response(400, [])
    end
  end

  defp callback_page(header, scheme) do
    current_origin = origin(header, scheme)

    case decode_session(cookie(header)) do
      %{state: state, target: target, origin: ^current_origin} ->
        render_callback(state, target, scheme)

      _ ->
        restart_login(header, scheme, current_origin, nil)
    end
  end

  defp render_callback(state, target, scheme) do
    nonce = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    context = Jason.encode!(%{state: state, target: target}) |> String.replace("<", "\\u003c")
    secure = if scheme == "https", do: "; Secure", else: ""

    body = """
    <!doctype html><meta charset="utf-8"><title>Signing in</title>
    <script nonce="#{nonce}">
    const context = #{context};
    const params = new URLSearchParams(location.hash.slice(1));
    history.replaceState(null, '', location.pathname);
    const token = params.get('access_token');
    const target = new URL(context.target, location.origin);
    if (params.get('state') === context.state && token && /^[\\x21-\\x7e]+$/.test(token) && target.origin === location.origin) {
      const value = btoa(token).replace(/\\+/g, '-').replace(/\\//g, '_').replace(/=+$/, '');
      const expires = Number(params.get('expires_in'));
      const age = Number.isFinite(expires) && expires > 0 ? Math.min(3600, Math.floor(expires)) : 3600;
      const cookie = '#{@access_cookie}=' + value + '; Path=/; SameSite=Lax; Max-Age=' + age + '#{secure}';
      if (cookie.length <= 4096) {
        document.cookie = cookie;
      }
    }

    location.replace(target.href);
    </script>
    """

    {:browser_response,
     "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n" <>
       "Cache-Control: no-store\r\nReferrer-Policy: no-referrer\r\n" <>
       "Content-Security-Policy: default-src 'none'; script-src 'nonce-#{nonce}'; base-uri 'none'; frame-ancestors 'none'\r\n" <>
       "Content-Length: #{byte_size(body)}\r\nConnection: close\r\n\r\n" <> body}
  end

  defp request_session(header) do
    context = decode_session(cookie(header))
    cookies = (get_header(header, "cookie") || "") |> Cookies.decode()

    with %{} <- context,
         value when is_binary(value) <- cookies[@access_cookie],
         {:ok, token} <- Base.url_decode64(value, padding: false),
         true <- String.valid?(token) && Regex.match?(~r/\A[\x21-\x7e]+\z/, token) do
      Map.put(context, :token, token)
    else
      _ -> context
    end
  end

  defp revoke(header, scheme) do
    current_origin = origin(header, scheme)
    session = request_session(header)

    if current_origin && get_header(header, "origin") == current_origin do
      result = revoke_session_token(session, current_origin)

      case result do
        :ok ->
          restart_login(header, scheme, current_origin, session)

        :error ->
          response(500, [])
      end
    else
      restart_login(header, scheme, current_origin, session)
    end
  end

  defp revoke_session_token(%{token: value, origin: origin}, origin) do
    case Boruta.AccessTokensAdapter.get_by(value: value) do
      nil -> :ok
      token -> revoke_public_token(token)
    end
  end

  defp revoke_session_token(_session, _origin), do: :ok

  defp revoke_public_token(token) do
    case token.client.id == Boruta.ClientsAdapter.public!().id &&
           Boruta.AccessTokensAdapter.revoke(token) do
      {:ok, _} -> :ok
      false -> :ok
      _ -> :error
    end
  end

  defp restart_login(header, scheme, current_origin, session) do
    context =
      case session do
        %{origin: ^current_origin} -> session
        _ -> %{}
      end

    scopes = Boruta.Oauth.Scope.split(context[:scope] || "")

    upstream = %BorutaGateway.Upstreams.Upstream{
      required_scopes: %{"GET" => scopes},
      oauth_session_flow: context[:oauth_session_flow] || "verifiable_presentation",
      oauth_session_wallet_uri: context[:oauth_session_wallet_uri]
    }

    begin_login(header, "GET", upstream, current_origin, scheme, context[:target] || "/")
  end

  defp cookie(header) do
    (get_header(header, "cookie") || "") |> Cookies.decode() |> Map.get(@cookie)
  end

  defp origin(header, scheme) do
    host = get_header(header, "host")
    if host && Regex.match?(~r/\A[a-zA-Z0-9.\[\]:-]+\z/, host), do: scheme <> "://" <> host
  end

  defp get_header(header, name) do
    header
    |> String.split("\r\n")
    |> Enum.find_value(fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> if String.downcase(key) == name, do: String.trim(value)
        _ -> nil
      end
    end)
  end

  defp session_cookie(id, scheme) do
    @cookie <>
      "=" <>
      id <>
      "; Path=/; HttpOnly; SameSite=Lax; Max-Age=3600" <>
      if(scheme == "https", do: "; Secure", else: "")
  end

  defp response(status, headers) do
    if Enum.any?(headers, fn {key, value} -> key == "Set-Cookie" && byte_size(value) > 4096 end) do
      build_response(400, [])
    else
      build_response(status, headers)
    end
  end

  defp build_response(status, headers) do
    reason =
      %{
        204 => "No Content",
        302 => "Found",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        405 => "Method Not Allowed",
        500 => "Internal Server Error"
      }[status]

    headers = Enum.map_join(headers, "", fn {key, value} -> key <> ": " <> value <> "\r\n" end)

    {:browser_response,
     "HTTP/1.1 #{status} #{reason}\r\n" <>
       headers <>
       "Cache-Control: no-store\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"}
  end
end
