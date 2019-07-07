defmodule BorutaWeb.AuthorizationPlug do
  @moduledoc """
  TODO AuthorizationPlug documentation
  """
  import Plug.Conn

  def init(_), do: true

  def call(conn, _) do
    with ["Bearer " <> value] <- get_req_header(conn, "authorization"),
         {:ok, %Boruta.Oauth.Token{}} <- Boruta.Oauth.Authorization.Base.access_token(value: value) do
      conn
    else
      _error ->
        conn
        |> send_resp(:unauthorized, "")
        |> halt()
    end
  end
end
