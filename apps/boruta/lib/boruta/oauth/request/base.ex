defmodule Boruta.Oauth.Request.Base do
  @moduledoc false

  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.IntrospectRequest
  alias Boruta.Oauth.PasswordRequest
  alias Boruta.Oauth.RefreshTokenRequest
  alias Boruta.Oauth.RevokeRequest
  alias Boruta.Oauth.TokenRequest

  @spec authorization_header(req_headers :: list()) ::
  {:ok, header :: String.t()} |
  {:error, :no_authorization_header}
  def authorization_header(req_headers) do
    case Enum.find(
      req_headers,
      fn (header) -> elem(header, 0) == "authorization" end
    ) do
      {"authorization", header} -> {:ok, header}
      _ -> {:error, :no_authorization_header}
    end
  end

  def build_request(%{"grant_type" => "client_credentials"} = params) do
    {:ok, struct(ClientCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      scope: params["scope"]
    })}
  end
  def build_request(%{"grant_type" => "password"} = params) do
    {:ok, struct(PasswordRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      username: params["username"],
      password: params["password"],
      scope: params["scope"]
    })}
  end
  def build_request(%{"grant_type" => "authorization_code"} = params) do
    {:ok, struct(AuthorizationCodeRequest, %{
      client_id: params["client_id"],
      code: params["code"],
      redirect_uri: params["redirect_uri"]
    })}
  end
  def build_request(%{"grant_type" => "refresh_token"} = params) do
    {:ok, struct(RefreshTokenRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      refresh_token: params["refresh_token"],
      scope: params["scope"]
    })}
  end

  def build_request(%{"response_type" => "token"} = params) do
    {:ok, struct(TokenRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      resource_owner: params["resource_owner"],
      state: params["state"],
      scope: params["scope"]
    })}
  end
  def build_request(%{"response_type" => "code"} = params) do
    {:ok, struct(CodeRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      resource_owner: params["resource_owner"],
      state: params["state"],
      scope: params["scope"]
    })}
  end
  def build_request(%{"response_type" => "introspect"} = params) do
    {:ok, struct(IntrospectRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      token: params["token"]
    })}
  end
  def build_request(%{"token" => _} = params) do # revoke request
    {:ok, struct(RevokeRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      token: params["token"],
      token_type_hint: params["token_type_hint"]
    })}
  end
end
