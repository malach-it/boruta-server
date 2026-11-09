defmodule BorutaGateway.Authorization.OauthSession do
  @behaviour BorutaGateway.Authorization
  @moduledoc false
  @cookie "boruta_gateway_session"
  @access_cookie "boruta_gateway_access_token"
  @callback_path "/__implicit/callback"
  @ttl 3600
  @salt "boruta gateway browser session v1"

  def encode_session(session) do
    Plug.Crypto.encrypt(secret_key_base(), @salt, session, max_age: @ttl)
  end

  def decode_session(nil), do: nil

  def decode_session(value) do
    case Plug.Crypto.decrypt(secret_key_base(), @salt, value, max_age: @ttl) do
      {:ok, session} when is_map(session) -> session
      _ -> nil
    end
  end

  defp secret_key_base do
    secret =
      Application.get_env(:boruta_gateway, :session_secret_key_base) ||
        Application.fetch_env!(:boruta_identity, BorutaIdentityWeb.Endpoint)[:secret_key_base]

    if is_binary(secret) && byte_size(secret) >= 64 do
      secret
    else
      raise "gateway cookie sessions require SECRET_KEY_BASE of at least 64 bytes"
    end
  end

  def strip_cookie(header) do
    header
    |> String.split("\r\n")
    |> Enum.map(fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          if String.downcase(key) == "cookie" do
            cookies =
              value
              |> String.split(";")
              |> Enum.reject(fn item ->
                Enum.any?(
                  [@cookie, @access_cookie],
                  &String.starts_with?(String.trim(item), &1 <> "=")
                )
              end)
              |> Enum.join(";")

            key <> ":" <> cookies
          else
            line
          end

        _ ->
          line
      end
    end)
    |> Enum.join("\r\n")
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

  def authorize(header, method, upstream, scheme) do
    if upstream.authorize && upstream.authorization_type == "oauth_session" do
      origin = origin(header, scheme)
      session = request_session(header)

      authorized_header =
        case session do
          %{token: token, origin: ^origin} ->
            if get_header(header, "authorization"),
              do: header,
              else: header <> "\r\nAuthorization: Bearer " <> token

          _ ->
            header
        end

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

      result =
        case result do
          {:ok, token} when authorized_header != header ->
            if token.client.id == Boruta.ClientsAdapter.public!().id,
              do: result,
              else: BorutaGateway.Authorization.Helpers.unauthorized(upstream, nil)

          _ ->
            result
        end

      case result do
        {:unauthorized, _, _, _} ->
          begin_login(header, method, upstream, origin, scheme)

        result ->
          result
      end
    else
      BorutaGateway.Authorization.authorize(header, method, upstream)
    end
  end

  defp begin_login(header, method, upstream, origin, scheme, return_to \\ nil) do
    [_, request_target | _] = String.split(header, " ", parts: 3)
    target = return_to || request_target

    if origin && String.starts_with?(target, "/") && !String.starts_with?(target, "//") do
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
          scope: Enum.join(scopes, " ")
        })

      query =
        URI.encode_query(%{
          client_id: client.id,
          redirect_uri: origin <> @callback_path,
          response_type: "token",
          scope: Enum.join(scopes, " "),
          state: state
        })

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
    cookies = (get_header(header, "cookie") || "") |> Plug.Conn.Cookies.decode()

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
      result =
        case session do
          %{token: value, origin: ^current_origin} ->
            case Boruta.AccessTokensAdapter.get_by(value: value) do
              nil ->
                :ok

              token ->
                case token.client.id == Boruta.ClientsAdapter.public!().id &&
                       Boruta.AccessTokensAdapter.revoke(token) do
                  {:ok, _} -> :ok
                  false -> :ok
                  _ -> :error
                end
            end

          _ ->
            :ok
        end

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

  defp restart_login(header, scheme, current_origin, session) do
    context =
      case session do
        %{origin: ^current_origin} -> session
        _ -> %{}
      end

    scopes = Boruta.Oauth.Scope.split(context[:scope] || "")
    upstream = %BorutaGateway.Upstreams.Upstream{required_scopes: %{"GET" => scopes}}
    begin_login(header, "GET", upstream, current_origin, scheme, context[:target] || "/")
  end

  defp cookie(header) do
    (get_header(header, "cookie") || "") |> Plug.Conn.Cookies.decode() |> Map.get(@cookie)
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
