defmodule Boruta.Oauth do
  @moduledoc """
  TODO Boruta OAuth
  """

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ImplicitRequest
  alias Boruta.Oauth.Introspect
  alias Boruta.Oauth.Request

  def token(conn, module) do
    with {:ok, request} <- Request.token_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.token_success(conn, token)
    else
      {:error, %Error{} = error} ->
        module.token_error(conn, error)
    end
  end

  def authorize(conn, module) do
    with {:ok, request} <- Request.authorize_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.authorize_success(conn, token)
    else
      {:error, %Error{} = error} ->
        with {:ok, request} <- Request.authorize_request(conn) do
          module.authorize_error(conn, error_with_format(request, error))
        else
          _ ->
            module.authorize_error(conn, error)
        end
    end
  end

  def introspect(conn, module) do
    with {:ok, request} <- Request.introspect_request(conn),
         {:ok, response} <- Introspect.token(request) do
      module.introspect_success(conn, response)
    else
      {:error, %Error{} = error} ->
        module.introspect_error(conn, error)
    end
  end

  defp error_with_format(%CodeRequest{redirect_uri: redirect_uri}, %Error{} = error) do
    %{error | format: :query, redirect_uri: redirect_uri}
  end
  defp error_with_format(%ImplicitRequest{redirect_uri: redirect_uri}, %Error{} = error) do
    %{error | format: :fragment, redirect_uri: redirect_uri}
  end
  defp error_with_format(_, error), do: error
end
