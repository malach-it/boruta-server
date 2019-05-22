defmodule Boruta.Oauth.Request do
  alias Boruta.Oauth.Validator
  alias Boruta.Oauth.Schema
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.BasicAuth

  def token_request(%{
    req_headers: [{"authorization", authorization_header}],
    query_params: %{} = query_params,
    body_params: %{} = body_params
  }) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header) do
    else
      {:error, error} ->
        {:unauthorized, %{error: "invalid_client", error_description: error}}
    end
  end
  def token_request(%{body_params: %{} = body_params}) do
    with %{} = params <- Validator.validate(body_params, Schema.client_credentials) do
      build_request(params)
    else
      {:error, error_description} ->
        {:bad_request, %{error: "invalid_request", error_description: error_description}}
    end
  end
  def token_request(_), do: {:bad_request, %{error: "invalid_request", error_description: "Must provide body_params"}}

  defp build_request(%{"grant_type" => "client_credentials"} = params) do
    {:ok, struct(ClientCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      scope: params["scope"] || ""
    })}
  end
end
