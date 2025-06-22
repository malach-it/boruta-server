defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  alias Boruta.Oauth.Client
  alias BorutaIdentity.Accounts.VerifiableCredentials
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
      # "registration_endpoint" =>
      #   issuer <> routes.dynamic_registration_path(BorutaWeb.Endpoint, :register_client),
      "pushed_authorization_request_endpoint" =>
        issuer <> routes.pushed_authorization_request_path(BorutaWeb.Endpoint, :pushed_authorization_request),
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
      "userinfo_signing_alg_values_supported" => Client.Crypto.signature_algorithms(),
      "credential_issuer" => issuer,
      "credential_endpoint" => issuer <> routes.credential_path(BorutaWeb.Endpoint, :credential),
      "defered_credential_endpoint" => issuer <> routes.credential_path(BorutaWeb.Endpoint, :defered_credential),
      "credential_configurations_supported" =>
        VerifiableCredentials.credential_configurations_supported(),
      "credentials_supported" => VerifiableCredentials.credentials_supported()
    }
  end

  def render("openid_credential_issuer.json", %{routes: routes}) do
    issuer = Boruta.Config.issuer()

    %{
      "issuer" => issuer,
      "token_endpoint" => issuer <> routes.token_path(BorutaWeb.Endpoint, :token),
      "credential_issuer" => issuer,
      "credential_endpoint" => issuer <> routes.credential_path(BorutaWeb.Endpoint, :credential),
      "credential_configurations_supported" =>
        VerifiableCredentials.credential_configurations_supported(),
      "credentials_supported" => VerifiableCredentials.credentials_supported()
    }
  end

  def render("credential.json", %{credential_response: credential_response}) do
    %{
      format: credential_response.format,
      credential: credential_response.credential
    }
    # TODO use associated access token c_nonce
    |> Map.put(:c_nonce, "boruta")
    |> Map.put(:c_nonce_expires_in, 3600)
  end

  def render("defered_credential.json", %{credential_response: credential_response}) do
    %{
      acceptance_token: credential_response.acceptance_token,
      c_nonce: credential_response.c_nonce,
      c_nonce_expires_in: credential_response.c_nonce_expires_in
    }
  end

  def render("pushed_authorization_request.json", %{
        response: %Boruta.Oauth.PushedAuthorizationResponse{} = response
      }) do
    response
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.TokenResponse do
    def encode(
          %Boruta.Oauth.TokenResponse{
            token_type: token_type,
            access_token: access_token,
            agent_token: agent_token,
            id_token: id_token,
            c_nonce: c_nonce,
            expires_in: expires_in,
            refresh_token: refresh_token,
            authorization_details: authorization_details
          },
          options
        ) do
      response = %{
        token_type: token_type,
        expires_in: expires_in,
        refresh_token: refresh_token,
        c_nonce: c_nonce
      }

      response =
        case id_token do
          nil -> response
          id_token -> Map.put(response, :id_token, id_token)
        end

      response =
        case access_token do
          nil -> response
          access_token -> Map.put(response, :access_token, access_token)
        end

      response =
        case agent_token do
          nil -> response
          agent_token -> Map.put(response, :agent_token, agent_token)
        end

      response =
        case authorization_details do
          nil ->
            response

          _authorization_details ->
            response
            |> Map.put(:authorization_details, authorization_details)
            |> Map.put(:c_nonce_expires_in, 3600)
        end

      Jason.Encode.map(
        response,
        options
      )
    end
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.IntrospectResponse do
    def encode(
          %Boruta.Oauth.IntrospectResponse{
            active: false
          },
          options
        ) do
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

  defimpl Jason.Encoder, for: Boruta.Oauth.PushedAuthorizationResponse do
    def encode(%Boruta.Oauth.PushedAuthorizationResponse{} = response, options) do
      Jason.Encode.map(
        %{
          request_uri: response.request_uri,
          expires_in: response.expires_in
        },
        options
      )
    end
  end
end
