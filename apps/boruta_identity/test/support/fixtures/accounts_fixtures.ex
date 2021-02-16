defmodule BorutaIdentity.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaIdentity.Accounts` context.
  """

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @password "hello world!"
  @hashed_password Argon2.hash_pwd_salt(@password)

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: @password

  def user_fixture(attrs \\ %{}) do
    # TODO user with static password to speed up tests
    {:ok, user} = Repo.insert(%User{
      email: unique_user_email(),
      hashed_password: @hashed_password
    } |> Ecto.Changeset.change(attrs))
    user
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end
end
