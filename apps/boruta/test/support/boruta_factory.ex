defmodule Boruta.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Boruta.Repo

  alias Boruta.Accounts.HashSalt
  alias Boruta.Accounts.User
  alias Boruta.Ecto

  def client_factory do
    %Ecto.Client{
      secret: SecureRandom.urlsafe_base64(),
      redirect_uris: ["https://redirect.uri/oauth2-redirect-path"]
    }
  end

  def scope_factory do
    %Ecto.Scope{
      name: SecureRandom.hex(10),
      public: false
    }
  end

  def token_factory do
    %Ecto.Token{
      type: "access_token",
      value: Boruta.TokenGenerator.generate(),
      expires_at: :os.system_time(:seconds) + 10
    }
  end
end
