defmodule Boruta.Factory do
  use ExMachina.Ecto, repo: Boruta.Repo
  use Authable.RepoBase

  def client_factory do
    %@client{
      name: sequence(:name, &"client#{&1}"),
      secret: SecureRandom.urlsafe_base64(),
      redirect_uri: "https://example.com/oauth2-redirect-path",
      settings: %{
        name: "example",
        icon: "https://example.com/icon.png"
      }
    }
  end

  def user_factory do
    %Boruta.Coherence.User{
      email: sequence(:email, &"foo-#{&1}@example.com"),
      password: "password",
      password_hash: Boruta.Coherence.User.encrypt_password("password")
    }
  end
end
