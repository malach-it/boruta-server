defmodule Boruta.Oauth.Request do
  alias Boruta.Oauth.Validator
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest
  alias Boruta.BasicAuth

  def token_request(%Plug.Conn{
    req_headers: req_headers,
    body_params: %{} = body_params
  }) do
    with {"authorization", authorization_header} <- Enum.find(req_headers, fn (header) -> elem(header, 0) == "authorization" end) do
      token_request(%{
        req_headers: [{"authorization", authorization_header}],
        body_params: %{} = body_params
      })
    else
      nil ->
        token_request(%{body_params: %{} = body_params})
    end
  end
  def token_request(%{
    req_headers: [{"authorization", authorization_header}],
    body_params: %{} = body_params
  }) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         %{} = params <- Validator.validate(
           Enum.into(body_params, %{"client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:bad_request, %{error: "invalid_request", error_description: error}}
    end
  end
  def token_request(%{body_params: %{} = body_params}) do
    with %{} = params <- Validator.validate(body_params) do
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
  defp build_request(%{"grant_type" => "password"} = params) do
    {:ok, struct(ResourceOwnerPasswordCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      username: params["username"],
      password: params["password"],
      scope: params["scope"] || ""
    })}
  end
end
