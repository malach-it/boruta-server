defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  def render("token.json", %{token: %Boruta.Oauth.Token{} = token}) do
    token
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
        expires_in: expires_in
        # refresh_token: token.details[:refresh_token]
      }, options)
    end
  end
end
