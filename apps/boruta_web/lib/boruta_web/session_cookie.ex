defmodule BorutaWeb.SessionCookie do
  @moduledoc false

  import Plug.Conn

  @max_cookie_size 4096

  def clean_if_oversized(conn, client_id, request) do
    config = Plug.Session.init(BorutaWeb.Endpoint.session_options())

    if cookie_size(conn, config) <= @max_cookie_size do
      {:ok, conn}
    else
      conn = prune_stale_entries(conn, request)

      if cookie_size(conn, config) <= @max_cookie_size do
        {:ok, conn}
      else
        conn = keep_current_session(conn, client_id)

        if cookie_size(conn, config) <= @max_cookie_size do
          {:ok, conn}
        else
          {:error, clear_session(conn)}
        end
      end
    end
  end

  defp cookie_size(conn, config) do
    value = config.store.put(conn, nil, get_session(conn), config.store_config)
    cookie = Map.new(config.cookie_opts) |> Map.put(:value, value)
    byte_size(Plug.Conn.Cookies.encode(config.key, cookie))
  end

  defp prune_stale_entries(conn, request) do
    conn
    |> keep_map_entries(:preauthorizations, [request])
    |> prune_mfa_entries()
  end

  defp keep_current_session(conn, client_id) do
    conn
    |> keep_map_entries(:user_token, [client_id])
    |> prune_mfa_entries()
  end

  defp prune_mfa_entries(conn) do
    tokens =
      case get_session(conn, :user_token) do
        tokens when is_map(tokens) -> Map.values(tokens)
        _ -> []
      end

    conn
    |> keep_map_entries(:totp_authenticated, tokens)
    |> keep_map_entries(:webauthn_authenticated, tokens)
  end

  defp keep_map_entries(conn, key, keys) do
    case get_session(conn, key) do
      entries when is_map(entries) -> put_session(conn, key, Map.take(entries, keys))
      _ -> delete_session(conn, key)
    end
  end
end
