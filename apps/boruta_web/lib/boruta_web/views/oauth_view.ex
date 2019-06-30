defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  def render("token.json", %{token: %Boruta.Oauth.Token{} = token}) do
    token
  end

  def render("introspect.json", %{active: false}) do
    %{"active" => false}
  end
  def render("introspect.json", %{token: %Boruta.Oauth.Token{
    client: client,
    resource_owner: resource_owner,
    expires_at: expires_at,
    scope: scope,
    inserted_at: inserted_at
  }}) do
    %{
      "active" => true,
      "client_id" => client.id,
      "username" => resource_owner && resource_owner.email,
      "scope" => scope,
      "sub" => resource_owner && resource_owner.id,
      "iss" => "boruta", # TODO change to hostname
      "exp" => expires_at,
      "iat" => DateTime.to_unix(inserted_at)
    }
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  defimpl Jason.Encoder, for: Boruta.Oauth.Token do
    def encode(token, options) do
      {:ok, expires_at} = DateTime.from_unix(token.expires_at)
      expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

      Jason.Encode.map(%{
        access_token: token.value,
        token_type: "bearer",
        expires_in: expires_in,
        refresh_token: token.refresh_token
      }, options)
    end
  end
end
