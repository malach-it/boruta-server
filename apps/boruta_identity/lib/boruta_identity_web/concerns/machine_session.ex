defmodule BorutaIdentityWeb.MachineSession do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentityWeb.Authenticable

  def from_session_authorize(
        %Plug.Conn{query_params: params, assigns: %{current_user: user}} = conn
      ) do
    with %User{id: user_id, account_type: "machine"} <- user,
         %{code: code, client_id: client_id, user_id: ^user_id} <-
           Plug.Conn.get_session(conn, :machine_authorization),
         ^code <- params["code"],
         ^client_id <- params["client_id"],
         "did:" <> _ <- client_id do
      user
    else
      _ -> nil
    end
  end

  def from_session_authorize(_conn), do: nil

  def from_session_consent(%Plug.Conn{assigns: %{current_user: user}} = conn) do
    with "did:" <> _key = client_id <- Authenticable.client_id_from_request(conn),
         "" <> return_to <- Authenticable.user_return_to_from_request(conn),
         %URI{path: "/oauth/authorize", query: query} <- URI.parse(return_to),
         %{"client_id" => ^client_id} = params <- URI.decode_query(query || "") do
      from_session_authorize(%{conn | query_params: params, assigns: %{current_user: user}})
    else
      _ -> nil
    end
  end

  def from_session_consent(_conn), do: nil
end
