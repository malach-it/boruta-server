defmodule BorutaWeb.AuthorizationPlug do
  @moduledoc """
  TODO AuthorizationPlug documentation
  TODO unit test
  TODO typespec
  """
  import Plug.Conn

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token

  def init(required_scopes), do: required_scopes || []

  def call(conn, required_scopes) do
    with ["Bearer " <> value] <- get_req_header(conn, "authorization"),
         {:ok, %Token{scope: scope} = token} <- Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, required_scopes)
    do
      assign(conn, :token, token)
    else
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
