defmodule Boruta.Oauth.Request do
  alias Boruta.Oauth.Validator
  alias Boruta.Oauth.Schema
  alias Boruta.Oauth.ClientCredentialsRequest

  def token_request(%{query_params: %{} = query_params, body_params: %{} = body_params}) do
    with %{
      "grant_type" => grant_type
    } <- Validator.validate(query_params, Schema.token(:query_params)),
    %{} = params <- Validator.validate(body_params, Schema.token(:body_params)) do
      params |> build_request(grant_type)
    else
      {:error, error_description} ->
        {:bad_request, %{error: "invalid_request", error_description: error_description}}
    end
  end
  def token_request(_), do: {:bad_request, %{error: "invalid_request", error_description: "Must provide query_params and body_params"}}

  defp build_request(params, "client_credentials") do
    {:ok, struct(ClientCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      scope: params["scope"] || ""
    })}
  end
end
