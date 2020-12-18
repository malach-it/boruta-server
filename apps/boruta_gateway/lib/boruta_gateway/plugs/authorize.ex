defmodule BorutaGateway.Plug.Authorize do
  @moduledoc false

  import Plug.Conn

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token
  alias BorutaGateway.Upstreams.Upstream

  require Logger

  def init(options), do: options

  def call(%Plug.Conn{
    assigns: %{upstream: upstream}
  } = conn, _options) do
    with %Upstream{authorize: true, required_scopes: required_scopes} <- upstream,
         ["Bearer " <> value] <- get_req_header(conn, "authorization"),
         {:ok, %Token{scope: scope} = token} <- Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, required_scopes)
    do
      assign(conn, :token, token)
    else
      %Upstream{authorize: false} ->
        conn
      {:error, "required scopes are not present."} ->
        conn
        |> send_resp(:forbidden, "")
        |> halt()
      _error ->
        conn
        |> send_resp(:unauthorized, "")
        |> halt()
    end
  end

  defp validate_scopes(scope, required_scopes) do
    scopes = Scope.split(scope)
    case Enum.empty?(required_scopes -- scopes) do
      true -> {:ok, scopes}
      false -> {:error, "required scopes are not present."}
    end
  end
end
