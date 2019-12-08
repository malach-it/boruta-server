defmodule Boruta.Oauth.Request.Token do
  @moduledoc false

  import Boruta.Oauth.Request.Base

  alias Boruta.BasicAuth
  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.PasswordRequest
  alias Boruta.Oauth.TokenRequest
  alias Boruta.Oauth.Validator

  @spec request(conn :: Plug.Conn.t() | map()) ::
    {:error,
     %Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, oauth_request :: %AuthorizationCodeRequest{}
      | %ClientCredentialsRequest{}
      | %AuthorizationCodeRequest{}
      | %TokenRequest{}
      | %PasswordRequest{}}
  # Handle Plug.Conn to extract header authorization (could not implement that as a guard)
  def request(%{
    req_headers: req_headers,
    body_params: %{} = body_params
  }) when is_list(req_headers) and length(req_headers) > 1 do
    case authorization_header(req_headers) do
      {:ok, authorization_header} ->
        request(%{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{} = body_params
        })
      {:error, _reason} ->
        request(%{body_params: %{} = body_params})
    end
  end

  def request(%{req_headers: [{"authorization", "Basic " <> _ = authorization_header}], body_params: %{} = body_params}) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         {:ok, params} <- Validator.validate(
           :token,
           Enum.into(body_params, %{"client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error}}
    end
  end
  def request(%{body_params: %{} = body_params}) do
    case Validator.validate(:token, body_params) do
      {:ok, params} ->
        build_request(params)
      {:error, error_description} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error_description}}
    end
  end
  def request(%{}) do
    {:error, %Error{status: :bad_request, error: :invalid_request, error_description: "Must provide body_params."}}
  end
end
