defmodule Boruta.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Boruta.Repo

  alias Boruta.Coherence.User

  def client_factory do
    %Boruta.Oauth.Client{
      secret: SecureRandom.urlsafe_base64(),
      redirect_uri: "https://redirect.uri/oauth2-redirect-path"
    }
  end

  def user_factory do
    %User{
      email: sequence(:email, &"foo-#{&1}@example.com"),
      password: "password",
      password_hash: User.encrypt_password("password")
    }
  end

  def token_factory do
    %Boruta.Oauth.Token{
      value: Boruta.TokenGenerator.generate(),
      expires_at: :os.system_time(:seconds) + 10
    }
  end
end
