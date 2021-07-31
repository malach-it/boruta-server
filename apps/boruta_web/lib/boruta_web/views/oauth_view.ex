defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  alias Boruta.Ecto
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

    signer =
      Joken.Signer.create(
        "HS512",
        Application.get_env(:boruta_web, BorutaWeb.Endpoint)[:secret_key_base]
      )

    with {:ok, token, _payload} <- Token.encode_and_sign(payload, signer) do
      token
    end
  end

  def render("introspect.jwt", %{
        response: %Boruta.Oauth.IntrospectResponse{private_key: private_key} = response
      }) do
    payload =
      response
      |> Map.delete(:private_key)
      |> Map.from_struct()

    signer = Joken.Signer.create("RS512", %{"pem" => private_key})

    with {:ok, token, _payload} <- Token.encode_and_sign(payload, signer) do
      token
    end
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  def render("jwks.json", %{clients: clients}) do
    keys = Enum.map(clients, fn (%Ecto.Client{id: client_id, public_key: public_key}) ->
      {_type, jwk} = public_key |> :jose_jwk.from_pem() |> :jose_jwk.to_map()

      Map.put(jwk, :kid, client_id)
    end)

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
