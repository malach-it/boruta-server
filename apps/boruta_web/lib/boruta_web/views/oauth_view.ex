defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  alias Boruta.Ecto
  alias Boruta.Oauth.IdToken
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

  def render("jwks.json", %{keys: keys}) do
    %{
      keys: keys
    }
  end

  def render("jwk.json", %{client: %Ecto.Client{id: client_id, public_key: public_key}}) do
    {_type, jwk} = public_key |> :jose_jwk.from_pem() |> :jose_jwk.to_map()

    %{
      keys: [Map.put(jwk, :kid, client_id)]
    }
  end

  def render("well_known.json", %{routes: routes}) do
    issuer = Boruta.Config.issuer()

    %{
      "issuer" => issuer,
      "authorization_endpoint" => issuer <> routes.authorize_path(BorutaWeb.Endpoint, :authorize),
      "token_endpoint" => issuer <> routes.token_path(BorutaWeb.Endpoint, :token),
      "userinfo_endpoint" => issuer <> routes.openid_path(BorutaWeb.Endpoint, :userinfo),
      "jwks_uri" => issuer <> routes.openid_path(BorutaWeb.Endpoint, :jwks_index),
      "registration_endpoint" => issuer <> routes.openid_path(BorutaWeb.Endpoint, :register_client),
      "response_types_supported" => ["code", "token", "id_token", "code token", "code id_token", "code id_token token"],
      "response_modes_supported" => ["query", "fragment"],
      "subject_types_supported" => ["public"],
      "id_token_signing_alg_values_supported" => IdToken.signature_algorithms()
    }
  end

  def render("userinfo.json", %{userinfo: userinfo}) do
    userinfo
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
    def encode(
          %Boruta.Oauth.IntrospectResponse{
            active: active,
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
      result =
        case active do
          true ->
            %{
              active: true,
              client_id: client_id,
              username: username,
              scope: scope,
              sub: sub,
              iss: iss,
              exp: exp,
              iat: iat
            }

          false ->
            %{active: false}
        end

      Jason.Encode.map(result, options)
    end
  end
end
