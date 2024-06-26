defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  alias Boruta.Oauth.Client
  alias BorutaWeb.Token

  def render("token.json", %{response: %Boruta.Oauth.TokenResponse{} = response}) do
    response
  end

  def render("introspect.json", %{response: %Boruta.Oauth.IntrospectResponse{active: false}}) do
    %{"active" => false}
  end

  def render("introspect.json", %{response: %Boruta.Oauth.IntrospectResponse{} = response}) do
    response
  end

  def render("introspect.jwt", %{response: %Boruta.Oauth.IntrospectResponse{active: false}}) do
    payload = %{"active" => false}

    {:ok, token, _payload} = Joken.encode_and_sign(payload, Token.application_signer())

    token
  end

  def render("introspect.jwt", %{
        response: %Boruta.Oauth.IntrospectResponse{private_key: private_key} = response
      }) do
    payload =
      response
      |> Map.delete(:private_key)
      |> Map.from_struct()

    signer = Joken.Signer.create("RS512", %{"pem" => private_key})
    {:ok, token, _payload} = Joken.encode_and_sign(payload, signer)

    token
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  def render("well_known.json", %{routes: routes, scopes: scopes}) do
    issuer = Boruta.Config.issuer()

    %{
      "issuer" => issuer,
      "authorization_endpoint" => issuer <> routes.authorize_path(BorutaWeb.Endpoint, :authorize),
      "token_endpoint" => issuer <> routes.token_path(BorutaWeb.Endpoint, :token),
      "userinfo_endpoint" => issuer <> routes.userinfo_path(BorutaWeb.Endpoint, :userinfo),
      "jwks_uri" => issuer <> routes.jwks_path(BorutaWeb.Endpoint, :jwks_index),
      "registration_endpoint" =>
        issuer <> routes.dynamic_registration_path(BorutaWeb.Endpoint, :register_client),
      "grant_types_supported" => [
        "client_credentials",
        "password",
        "implicit",
        "authorization_code",
        "refresh_token"
      ],
      "response_types_supported" => [
        "code",
        "token",
        "id_token",
        "code token",
        "code id_token",
        "token id_token",
        "code id_token token"
      ],
      "scopes_supported" => Enum.map(scopes, fn scope -> scope.name end),
      "response_modes_supported" => ["query", "fragment"],
      "subject_types_supported" => ["public"],
      "token_endpoint_auth_methods_supported" => [
        "client_secret_basic",
        "client_secret_post",
        "client_secret_jwt",
        "private_key_jwt"
      ],
      "request_object_signing_alg_values_supported" => Client.Crypto.signature_algorithms(),
      "id_token_signing_alg_values_supported" => Client.Crypto.signature_algorithms(),
      "userinfo_signing_alg_values_supported" => Client.Crypto.signature_algorithms()
    }
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.TokenResponse do
    def encode(
          %Boruta.Oauth.TokenResponse{
            token_type: token_type,
            access_token: access_token,
            id_token: id_token,
            expires_in: expires_in,
            refresh_token: refresh_token
          },
          options
        ) do
      response = %{
        token_type: token_type,
        access_token: access_token,
        expires_in: expires_in,
        refresh_token: refresh_token
      }

      response =
        case id_token do
          nil -> response
          id_token -> Map.put(response, :id_token, id_token)
        end

      Jason.Encode.map(
        response,
        options
      )
    end
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.IntrospectResponse do
    def encode(%Boruta.Oauth.IntrospectResponse{
          active: false
        }, options) do
      Jason.Encode.map(%{active: false}, options)
    end

    def encode(
          %Boruta.Oauth.IntrospectResponse{
            active: true,
            client_id: client_id,
            username: username,
            scope: scope,
            sub: sub,
            iss: iss,
            exp: exp,
            iat: iat
          },
          options
        ) do
      Jason.Encode.map(
        %{
          active: true,
          client_id: client_id,
          username: username,
          scope: scope,
          sub: sub,
          iss: iss,
          exp: exp,
          iat: iat
        },
        options
      )
    end
  end
end
