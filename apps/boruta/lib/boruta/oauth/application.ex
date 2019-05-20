defmodule Boruta.Oauth.Application do
  @callback token_success(conn :: Plug.Conn.t(), token :: Authable.Model.Token.t()) :: Plug.Conn.t()
  @callback token_error(conn :: Plug.Conn.t(), {status :: atom(), Map.t()}) :: Plug.Conn.t()
end
