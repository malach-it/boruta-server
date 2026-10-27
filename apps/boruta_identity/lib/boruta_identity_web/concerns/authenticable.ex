defmodule BorutaIdentityWeb.Authenticable do
  @moduledoc false

  use BorutaIdentityWeb, :controller

  alias Boruta.Oauth
  alias BorutaIdentity.Accounts
  alias BorutaIdentity.IdentityProviders

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @session_key :user_token
  @max_age 60 * 60 * 24 * 60
  @default_remember_me_cookie "_boruta_identity_web_user_remember_me"
  @authorization_request_key :authorization_request
  @remember_me_options [sign: true, max_age: @max_age, secure: true, same_site: "Lax"]

  @spec remember_me_cookie(client_id :: String.t()) :: String.t()
  def remember_me_cookie(client_id) do
    (:boruta_identity
    |> Application.get_env(BorutaIdentityWeb.Authenticable, [])
    |> Keyword.get(:remember_me_cookie, @default_remember_me_cookie)) <>
      "-#{client_id}"
  end

  @spec store_user_session(conn :: Plug.Conn.t(), session_token :: String.t()) ::
          conn :: Plug.Conn.t()
  @spec store_user_session(conn :: Plug.Conn.t(), session_token :: String.t(), client_id :: String.t()) ::
          conn :: Plug.Conn.t()
  def store_user_session(%Plug.Conn{body_params: params} = conn, session_token, client_id \\ nil) do
    user = session_token && Accounts.get_user_by_session_token(session_token)

    client_id = client_id || client_id_from_request(conn)
    session = case get_session(conn, @session_key) do
      nil -> %{}
      "" <> _token -> %{}
      session -> session
    end

    conn
    |> assign(:current_user, user)
    |> put_session(@session_key, Map.put(session, client_id, session_token))
    |> maybe_write_remember_me_cookie(session_token, params["user"])
  end

  @spec get_user_session(conn :: Plug.Conn.t()) :: session_token :: String.t()
  def get_user_session(conn) do
    client_id = client_id_from_request(conn) || conn.query_params["client_id"]
    session = case get_session(conn, @session_key) do
      nil -> %{}
      "" <> _token -> %{}
      session -> session
    end

    Map.get(session, client_id)
  end

  @spec remove_user_session(conn :: Plug.Conn.t()) :: conn :: Plug.Conn.t()
  def remove_user_session(conn, client_id \\ nil) do
    client_id = client_id || client_id_from_request(conn)
    session = case get_session(conn, @session_key) do
      nil -> %{}
      "" <> _token -> %{}
      session -> session
    end

    conn
    |> delete_resp_cookie(remember_me_cookie(client_id))
    |> put_session(@session_key, Map.delete(session, client_id))
    |> delete_session(:machine_authorization)
    |> delete_session(:session_chosen)
    |> delete_session(:preauthorizations)
    |> delete_session(:totp_authenticated)
    |> delete_session(:webauthn_authenticated)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => remember_me})
       when remember_me in ["true", "on"] do
    client_id = client_id_from_request(conn)

    put_resp_cookie(conn, remember_me_cookie(client_id), token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  @spec after_sign_in_path(conn :: Plug.Conn.t()) :: String.t()
  def after_sign_in_path(conn), do: user_return_to_from_request(conn) || "/"

  @spec after_registration_path(conn :: Plug.Conn.t()) :: String.t()
  def after_registration_path(conn), do: user_return_to_from_request(conn) || "/"

  @spec after_sign_out_path(conn :: Plug.Conn.t()) :: String.t()
  def after_sign_out_path(%Plug.Conn{query_params: query_params} = conn) do
    Routes.user_session_path(conn, :new, query_params)
  end

  @spec request_param(conn :: Plug.Conn.t()) :: request_param :: String.t()
  def request_param(%Plug.Conn{assigns: %{request_param: request}}), do: request

  def request_param(conn) do
    case Oauth.Request.authorize_request(conn, %Oauth.ResourceOwner{sub: ""}) do
      {:ok, %_{client_id: client_id, scope: scope}} ->
        signed_request_param(conn, client_id, scope)

      _ ->
        ""
    end
  end

  @spec identity_request_params(conn :: Plug.Conn.t()) :: map()
  def identity_request_params(%Plug.Conn{assigns: %{request_param: _request}}), do: %{}
  def identity_request_params(conn), do: %{request: request_param(conn)}

  @spec prepare_request_param(conn :: Plug.Conn.t()) :: Plug.Conn.t()
  def prepare_request_param(conn) do
    with {:ok, %_{client_id: client_id, scope: scope}} <-
           Oauth.Request.authorize_request(conn, %Oauth.ResourceOwner{sub: ""}),
         %{request_mode: "stateful"} <-
           IdentityProviders.get_identity_provider_by_client_id(client_id) do
      jwt = signed_request_param(conn, client_id, scope)

      request =
        case get_session(conn, @authorization_request_key) do
          %{"id" => id, "jwt" => ^jwt} -> id
          _ -> SecureRandom.urlsafe_base64(24)
        end

      conn
      |> put_session(@authorization_request_key, %{"id" => request, "jwt" => jwt})
      |> assign(:request_param, request)
    else
      _ ->
        if get_session(conn, @authorization_request_key) do
          delete_session(conn, @authorization_request_key)
        else
          conn
        end
    end
  end

  defp signed_request_param(conn, client_id, scope) do
    {:ok, jwt, _payload} =
      Joken.encode_and_sign(
        request_claims(conn, client_id, scope),
        BorutaIdentityWeb.Token.application_signer()
      )

    jwt
  end

  defp request_claims(conn, client_id, scope) do
    %{
      "client_id" => client_id,
      "scope" => scope,
      "user_return_to" => user_return_to(conn)
    }
  end

  defp user_return_to(conn) do
    uri = current_path(conn) |> URI.parse()

    query =
      uri.query
      |> decode_query()
      |> Map.drop(["prompt", "max_age"])
      |> encode_query()

    uri
    |> Map.put(:query, query)
    |> URI.to_string()
  end

  defp decode_query(nil), do: %{}
  defp decode_query(query), do: URI.decode_query(query)

  defp encode_query(query) when query == %{}, do: nil
  defp encode_query(query), do: URI.encode_query(query)

  @spec scope_from_request(conn :: Plug.Conn.t()) :: String.t() | nil
  def scope_from_request(conn) do
    with {:ok, claims} <- claims_from_request(conn),
         {:ok, scope} when scope != :null <- Map.fetch(claims, "scope") do
      scope
    else
      _ -> ""
    end
  end

  @spec client_id_from_request(conn :: Plug.Conn.t()) :: String.t() | nil
  def client_id_from_request(conn) do
    with {:ok, claims} <- claims_from_request(conn),
         {:ok, client_id} when client_id != :null <- Map.fetch(claims, "client_id") do
      client_id
    else
      _ -> nil
    end
  end

  @spec user_return_to_from_request(conn :: Plug.Conn.t()) :: String.t() | nil
  def user_return_to_from_request(conn) do
    with {:ok, claims} <- claims_from_request(conn),
         {:ok, user_return_to} when user_return_to != :null <- Map.fetch(claims, "user_return_to") do
      user_return_to
    else
      _ -> nil
    end
  end

  defp claims_from_request(conn) do
    request = conn.query_params["request"] || conn.assigns[:request] || ""

    case get_session(conn, @authorization_request_key) do
      %{"id" => ^request, "jwt" => jwt} when request != "" ->
        BorutaIdentityWeb.Token.verify(jwt, BorutaIdentityWeb.Token.application_signer())

      %{"jwt" => jwt} when request == "" ->
        BorutaIdentityWeb.Token.verify(jwt, BorutaIdentityWeb.Token.application_signer())

      _ ->
        BorutaIdentityWeb.Token.verify(
          request,
          BorutaIdentityWeb.Token.application_signer()
        )
    end
  end
end
