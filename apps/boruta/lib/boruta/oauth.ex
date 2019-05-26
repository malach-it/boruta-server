defmodule Boruta.Oauth do
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.Authorization

  def token(conn, module) do
    with {:ok, request} <- Request.token_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.token_success(conn, token)
    else
      error ->
        module.token_error(conn, error)
    end
  end
end
