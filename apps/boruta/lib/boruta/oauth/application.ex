defmodule Boruta.Oauth.Application do
  @moduledoc """
  TODO OAuth application behaviour
  """

  @callback token_success(conn :: Plug.Conn.t(), token :: Boruta.Oauth.Token.t()) :: Plug.Conn.t()
  @callback token_error(conn :: Plug.Conn.t(), Boruta.Oauth.Error.t()) :: Plug.Conn.t()

  @callback authorize_success(conn :: Plug.Conn.t(), token :: Boruta.Oauth.Token.t())  :: Plug.Conn.t()
  @callback authorize_error(conn :: Plug.Conn.t(), Boruta.Oauth.Error.t()) :: Plug.Conn.t()

  @callback introspect_success(conn :: Plug.Conn.t(), response :: Boruta.Oauth.Introspect.t()) :: Plug.Conn.t()
  @callback introspect_error(conn :: Plug.Conn.t(), Boruta.Oauth.Error.t()) :: Plug.Conn.t()
end
