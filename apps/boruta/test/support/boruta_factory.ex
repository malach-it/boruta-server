defmodule Boruta.Factory do
  use ExMachina.Ecto, repo: Boruta.Repo

  def client_factory do
    %Boruta.Oauth.Client{
      secret: SecureRandom.urlsafe_base64(),
      redirect_uri: "https://redirect.uri/oauth2-redirect-path"
    }
  end

  def user_factory do
    %Boruta.Coherence.User{
      email: sequence(:email, &"foo-#{&1}@example.com"),
      password: "password",
      password_hash: Boruta.Coherence.User.encrypt_password("password")
    }
  end

  def token_factory do
    %Boruta.Oauth.Token{
      value: SecureRandom.urlsafe_base64(),
    }
  end
end
