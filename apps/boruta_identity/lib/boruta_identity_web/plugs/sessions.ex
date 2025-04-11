defmodule BorutaIdentityWeb.Sessions do
  @moduledoc false

  use BorutaIdentityWeb, :controller

  import BorutaIdentityWeb.Authenticable, only: [remember_me_cookie: 0, after_sign_in_path: 1]

  alias BorutaIdentity.Accounts

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  @spec fetch_current_user(conn :: Plug.Conn.t(), list()) :: conn :: Plug.Conn.t()
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [remember_me_cookie()])

      if user_token = conn.cookies[remember_me_cookie()] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  @spec redirect_if_user_is_authenticated(conn :: Plug.Conn.t(), list()) :: conn :: Plug.Conn.t()
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: after_sign_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  @spec require_authenticated_user(conn :: Plug.Conn.t(), list()) :: conn :: Plug.Conn.t()
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: Routes.user_session_path(conn, :new, conn.query_params))
      |> halt()
    end
  end
end
