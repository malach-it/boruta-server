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

  def authorize(%{assigns: %{current_user: _}} = conn, module) do
    with {:ok, request} <- Request.authorize_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.authorize_success(conn, token)
    else
      error ->
        module.authorize_error(conn, error)
    end
  end
  def authorize(conn, module) do
    authorize(%{query_params: conn[:query_params], assigns: %{current_user: nil}}, module)
  end
end
