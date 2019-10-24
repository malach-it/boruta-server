defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  def render("token.json", %{response: %Boruta.Oauth.TokenResponse{} = response}) do
    response
  end

  def render("introspect.json", %{active: false}) do
    %{"active" => false}
  end
  def render("introspect.json", %{response: %Boruta.Oauth.IntrospectResponse{} = response}) do
    response
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.TokenResponse do
    def encode(
      %Boruta.Oauth.TokenResponse{
        token_type: token_type,
        access_token: access_token,
        expires_in: expires_in,
        refresh_token: refresh_token
      },
      options
    ) do
      Jason.Encode.map(%{
        token_type: token_type,
        access_token: access_token,
        expires_in: expires_in,
        refresh_token: refresh_token
      }, options)
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
      result = case active do
        true -> %{
            active: true,
            client_id: client_id,
            username: username,
            scope: scope,
            sub: sub,
            iss: iss,
            exp: exp,
            iat: iat
        }
        false -> %{active: false}
      end
      Jason.Encode.map(result, options)
    end
  end
end
