defmodule BorutaWeb.OauthView do
  use BorutaWeb, :view

  alias BorutaWeb.OauthView
  alias Authable.Model.Token

  def render("token.json", %{token: %Token{} = token}) do
    token
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  defimpl Jason.Encoder, for: Token do
    def encode(token, options) do
      {:ok, expires_at} = DateTime.from_unix(token.expires_at)
      expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

      Jason.Encode.map(%{
        access_token: token.value,
        token_type: "bearer",
        expires_in: expires_in,
        refresh_token: token.details[:refresh_token]
      }, options)
    end
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end

  def render("token.json", %{token: %Token{} = token}) do
    token
  end

  defimpl Jason.Encoder, for: Token do
    def encode(token, options) do
      {:ok, expires_at} = DateTime.from_unix(token.expires_at)
      expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

      Jason.Encode.map(%{
        access_token: token.value,
        token_type: "bearer",
        expires_in: expires_in,
        refresh_token: token.details[:refresh_token]
      }, options)
    end
  end
end
