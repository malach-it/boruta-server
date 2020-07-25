defmodule BorutaIdentityProvider.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentityProvider.Repo

  alias BorutaIdentityProvider.Accounts.HashSalt
  alias BorutaIdentityProvider.Accounts.User
  alias BorutaIdentityProvider.Accounts.UserAuthorizedScope

  def user_factory do
    %User{
      password: "password",
      password_hash: HashSalt.hashpwsalt("password"),
      email: "#{SecureRandom.uuid}@test.test",
    }
  end

  def user_scope_factory do
    %UserAuthorizedScope{
      name: SecureRandom.hex
    }
  end
end
