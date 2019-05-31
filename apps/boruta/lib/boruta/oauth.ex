defmodule Boruta.Oauth do
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.ImplicitRequest
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

  def authorize(conn, module) do
    with {:ok, request} <- Request.authorize_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.authorize_success(conn, token)
    else
      error ->
        with {:ok, request} <- Request.authorize_request(conn) do
          module.authorize_error(conn, error_with_format(request, error))
        else
          _ ->
            module.authorize_error(conn, error)
        end
    end
  end

  defp error_with_format(%CodeRequest{redirect_uri: redirect_uri}, {status, error}) do
    {status, Enum.into(error, %{format: :query, redirect_uri: redirect_uri})}
  end
  defp error_with_format(%ImplicitRequest{redirect_uri: redirect_uri}, {status, error}) do
    {status, Enum.into(error, %{format: :fragment, redirect_uri: redirect_uri})}
  end
  defp error_with_format(_, error), do: error
end
