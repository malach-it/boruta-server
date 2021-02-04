defmodule BorutaIdentityWeb.Authenticable do
  @moduledoc false

  use BorutaIdentityWeb, :controller

  alias BorutaIdentity.Accounts

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_boruta_identity_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @spec remember_me_cookie() :: String.t()
  def remember_me_cookie, do: @remember_me_cookie

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  @spec log_in(conn :: Plug.Conn.t(), %Accounts.User{}) :: conn :: Plug.Conn.t()
  @spec log_in(conn :: Plug.Conn.t(), %Accounts.User{}, map()) :: conn :: Plug.Conn.t()
  def log_in(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || after_sign_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  @spec log_out_user(conn :: Plug.Conn.t()) :: conn :: Plug.Conn.t()
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      BorutaIdentityWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> delete_resp_cookie(@remember_me_cookie)
    # TODO renew session
    |> redirect(to: Routes.user_session_path(conn, :new))
  end

  # TODO test it
  @spec after_sign_in_path(conn :: Plug.Conn.t()) :: String.t()
  def after_sign_in_path(conn), do: get_session(conn, :user_return_to) || "/"
end
