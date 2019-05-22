defmodule Boruta.Oauth.Request do
  alias Boruta.Oauth.Validator
  alias Boruta.Oauth.Schema
  alias Boruta.Oauth.ClientCredentialsRequest

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
