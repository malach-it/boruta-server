defmodule Boruta.Oauth.Application do
  @moduledoc """
  OAuth application behaviour

  Implement this behaviour in the application layer of your OAuth provider.
  """

  @doc """
  This function will be triggered in case of success triggering `Boruta.Oauth.token/2`
  """
  @callback token_success(conn :: Plug.Conn.t(), token :: Boruta.Oauth.Token.t()) :: Plug.Conn.t()
  @doc """
  This function will be triggered in case of failure triggering `Boruta.Oauth.token/2`
  """
  @callback token_error(conn :: Plug.Conn.t(), oauth_error :: Boruta.Oauth.Error.t()) :: Plug.Conn.t()

  @doc """
  This function will be triggered in case of success triggering `Boruta.Oauth.authorize/2`
  """
  @callback authorize_success(conn :: Plug.Conn.t(), token :: Boruta.Oauth.Token.t())  :: Plug.Conn.t()
  @doc """
  This function will be triggered in case of failure triggering `Boruta.Oauth.authorize/2`
  """
  @callback authorize_error(conn :: Plug.Conn.t(), oauth_error :: Boruta.Oauth.Error.t()) :: Plug.Conn.t()

  @doc """
  This function will be triggered in case of success triggering `Boruta.Oauth.introspect/2`
  """
  @callback introspect_success(conn :: Plug.Conn.t(), response :: map()) :: Plug.Conn.t()
  @doc """
  This function will be triggered in case of failure triggering `Boruta.Oauth.introspect/2`
  """
  @callback introspect_error(conn :: Plug.Conn.t(), oauth_error :: Boruta.Oauth.Error.t()) :: Plug.Conn.t()
end
