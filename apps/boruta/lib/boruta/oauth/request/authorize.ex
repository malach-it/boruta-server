defmodule Boruta.Oauth.Request.Authorize do
  @moduledoc false

  import Boruta.Oauth.Request.Base

  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenRequest
  alias Boruta.Oauth.Validator

  @spec request(conn :: map(), resource_owner :: struct()) ::
    {:error,
     %Boruta.Oauth.Error{
       :error => :invalid_request,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, oauth_request :: %CodeRequest{}
      | %TokenRequest{}}
  def request(%{query_params: query_params}, resource_owner) do
    case Validator.validate(:authorize, query_params) do
      {:ok, params} ->
        # TODO have an explicit current_user param (request(conn :: Plug.Conn.t(), user :: any())
        build_request(Enum.into(params, %{"resource_owner" => resource_owner}))
      {:error, error_description} ->
        {:error, %Error{status: :bad_request, error: :invalid_request, error_description: error_description}}
    end
  end
  def request(%{}, _) do
    {:error, %Error{status: :bad_request, error: :invalid_request, error_description: "Must provide query_params."}}
  end
end
