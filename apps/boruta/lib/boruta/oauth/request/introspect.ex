defmodule Boruta.Oauth.Request.Introspect do
  @moduledoc false

  import Boruta.Oauth.Request.Base

  alias Boruta.BasicAuth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectRequest
  alias Boruta.Oauth.Validator

  @spec request(conn :: map() | map()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, request :: %IntrospectRequest{}}
  # Handle Plug.Conn to extract header authorization (could not implement that as a guard)
  def request(%{
    req_headers: req_headers,
    body_params: %{} = body_params
  }) when is_list(req_headers) and length(req_headers) > 1 do
    case authorization_header(req_headers) do
      nil ->
        request(%{body_params: %{} = body_params})
      authorization_header ->
        request(%{
          req_headers: [{"authorization", authorization_header}],
          body_params: %{} = body_params
        })
    end
  end

  def request(%{req_headers: [{"authorization", "Basic " <> _ = authorization_header}], body_params: %{} = body_params}) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         {:ok, params} <- Validator.validate(
           :introspect,
           Enum.into(body_params, %{"response_type" => "introspect", "client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error}}
    end
  end
  def request(%{body_params: %{} = body_params}) do
    case Validator.validate(:introspect, Enum.into(body_params, %{"response_type" => "introspect"})) do
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
