defmodule Boruta.Oauth do
  @moduledoc """
  Boruta OAuth entrypoint, handles OAuth requests.

  Note : this module works in association with `Boruta.Oauth.Application` behaviour
  """

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Introspect
  alias Boruta.Oauth.IntrospectResponse
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.Revoke
  alias Boruta.Oauth.TokenResponse

  @doc """
  Triggers `token_success` in case of success and `token_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.
  """
  @spec token(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def token(conn, module) do
    with {:ok, request} <- Request.token_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.token_success(
        conn,
        TokenResponse.from_token(token)
      )
    else
      {:error, %Error{} = error} ->
        module.token_error(conn, error)
    end
  end

  @doc """
  Triggers `authorize_success` in case of success and `authorize_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.

  Note : resource owner must be provided as current_user assigns.
  """
  @spec authorize(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def authorize(conn, module) do
    with {:ok, request} <- Request.authorize_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.authorize_success(
        conn,
        AuthorizeResponse.from_token(token)
      )
    else
      {:error, %Error{} = error} ->
        case Request.authorize_request(conn) do
          {:ok, request} ->
            module.authorize_error(conn, Error.with_format(error, request))
          _ ->
            module.authorize_error(conn, error)
        end
    end
  end

  @doc """
  Triggers `introspect_success` in case of success and `introspect_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.
  """
  @spec introspect(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def introspect(conn, module) do
    with {:ok, request} <- Request.introspect_request(conn),
         {:ok, token} <- Introspect.token(request) do
      module.introspect_success(conn, IntrospectResponse.from_token(token))
    else
      {:error, %Error{error: :invalid_access_token} = error} ->
        module.introspect_success(conn, IntrospectResponse.from_error(error))
      {:error, %Error{} = error} ->
        module.introspect_error(conn, error)
    end
  end

  @spec revoke(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def revoke(conn, module) do
    with {:ok, request} <- Request.revoke_request(conn),
         :ok <- Revoke.token(request) do
      module.revoke_success(conn)
    else
      {:error, error} ->
        module.revoke_error(conn, error)
    end
  end
end
