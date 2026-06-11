defmodule BorutaIdentityWeb.Authenticable do
  @moduledoc false

  use BorutaIdentityWeb, :controller

  alias Boruta.ClientsAdapter
  alias Boruta.Oauth
  alias BorutaIdentity.Accounts

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @session_key :user_token
  @max_age 60 * 60 * 24 * 60
  @default_remember_me_cookie "_boruta_identity_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, secure: true, same_site: "Lax"]

  @spec remember_me_cookie() :: String.t()
  def remember_me_cookie do
    :boruta_identity
    |> Application.get_env(BorutaIdentityWeb.Authenticable, [])
    |> Keyword.get(:remember_me_cookie, @default_remember_me_cookie)
  end

  @spec store_user_session(conn :: Plug.Conn.t(), session_token :: String.t()) ::
          conn :: Plug.Conn.t()
  def store_user_session(%Plug.Conn{body_params: params} = conn, session_token) do
    user = session_token && Accounts.get_user_by_session_token(session_token)

    conn
    |> assign(:current_user, user)
    |> put_session(@session_key, session_token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(session_token)}")
    |> maybe_write_remember_me_cookie(session_token, params["user"])
  end

  @spec get_user_session(conn :: Plug.Conn.t()) :: session_token :: String.t()
  def get_user_session(conn) do
    get_session(conn, @session_key)
  end

  @spec remove_user_session(conn :: Plug.Conn.t()) :: conn :: Plug.Conn.t()
  def remove_user_session(conn) do
    conn
    |> delete_resp_cookie(remember_me_cookie())
    |> delete_session(@session_key)
    |> delete_session(:session_chosen)
    |> delete_session(:preauthorizations)
    |> delete_session(:totp_authenticated)
    |> delete_session(:webauthn_authenticated)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => remember_me})
       when remember_me in ["true", "on"] do
    put_resp_cookie(conn, remember_me_cookie(), token, @remember_me_options)
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
  def request_param(conn) do
    case Oauth.Request.authorize_request(conn, %Oauth.ResourceOwner{sub: ""}) do
      {:ok, %_{client_id: "did:" <> _key, scope: scope}} ->
        {:ok, jwt, _payload} =
          Joken.encode_and_sign(
            %{
              "client_id" => ClientsAdapter.public!().id,
              "scope" => scope,
              "user_return_to" => user_return_to(conn)
            },
            BorutaIdentityWeb.Token.application_signer()
          )

        jwt

      {:ok, %_{client_id: client_id, scope: scope}} ->
        {:ok, jwt, _payload} =
          Joken.encode_and_sign(
            %{
              "client_id" => client_id,
              "scope" => scope,
              "user_return_to" => user_return_to(conn)
            },
            BorutaIdentityWeb.Token.application_signer()
          )

        jwt

      _ ->
        ""
    end
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
  def scope_from_request(%Plug.Conn{query_params: query_params}) do
    with {:ok, claims} <-
           BorutaIdentityWeb.Token.verify(
             query_params["request"] || "",
             BorutaIdentityWeb.Token.application_signer()
           ),
         {:ok, scope} <- Map.fetch(claims, "scope") do
      scope
    else
      _ -> nil
    end
  end

  @spec client_id_from_request(conn :: Plug.Conn.t()) :: String.t() | nil
  def client_id_from_request(%Plug.Conn{query_params: %{"request" => request}}) do
    with {:ok, claims} <-
           BorutaIdentityWeb.Token.verify(
             request || "",
             BorutaIdentityWeb.Token.application_signer()
           ),
         {:ok, client_id} <- Map.fetch(claims, "client_id") do
      client_id
    else
      _ -> nil
    end
  end

  def client_id_from_request(%Plug.Conn{assigns: %{request: request}}) do
    with {:ok, claims} <-
           BorutaIdentityWeb.Token.verify(
             request || "",
             BorutaIdentityWeb.Token.application_signer()
           ),
         {:ok, client_id} <- Map.fetch(claims, "client_id") do
      client_id
    else
      _ -> nil
    end
  end

  def client_id_from_request(_conn), do: nil

  @spec user_return_to_from_request(conn :: Plug.Conn.t()) :: String.t() | nil
  def user_return_to_from_request(%Plug.Conn{query_params: %{"request" => request}}) do
    with {:ok, claims} <-
           BorutaIdentityWeb.Token.verify(
             request || "",
             BorutaIdentityWeb.Token.application_signer()
           ),
         {:ok, user_return_to} <- Map.fetch(claims, "user_return_to") do
      user_return_to
    else
      _ -> nil
    end
  end

  def user_return_to_from_request(%Plug.Conn{assigns: %{request: request}}) do
    with {:ok, claims} <-
           BorutaIdentityWeb.Token.verify(
             request || "",
             BorutaIdentityWeb.Token.application_signer()
           ),
         {:ok, user_return_to} <- Map.fetch(claims, "user_return_to") do
      user_return_to
    else
      _ -> nil
    end
  end

  def user_return_to_from_request(_conn), do: nil
end
