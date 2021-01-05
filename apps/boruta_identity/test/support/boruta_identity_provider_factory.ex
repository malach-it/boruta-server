defmodule BorutaIdentity.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: BorutaIdentity.Repo

  alias BorutaIdentity.Accounts.HashSalt
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope

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
