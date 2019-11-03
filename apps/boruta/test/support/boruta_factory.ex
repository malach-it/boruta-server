defmodule Boruta.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Boruta.Repo

  alias Boruta.Accounts.HashSalt
  alias Boruta.Accounts.User

  def client_factory do
    %Boruta.Client{
      secret: SecureRandom.urlsafe_base64(),
      redirect_uris: ["https://redirect.uri/oauth2-redirect-path"]
    }
  end

  def scope_factory do
    %Boruta.Scope{
      name: SecureRandom.hex(10),
      public: false
    }
  end

  def user_factory do
    %User{
      email: sequence(:email, &"foo-#{&1}@example.com"),
      password: "password",
      password_hash: HashSalt.hashpwsalt("password")
    }
  end

  def token_factory do
    %Boruta.Token{
      value: Boruta.TokenGenerator.generate(),
      expires_at: :os.system_time(:seconds) + 10
    }
  end
end
