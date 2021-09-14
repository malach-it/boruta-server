defmodule BorutaIdentity.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaIdentity.Accounts` context.
  """

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Repo

  @password "hello world!"
  @hashed_password "$argon2id$v=19$m=131072,t=8,p=4$9lPv7KsJogno0FlnhaRQXA$TeTY9FYjR1HJtZzg+N1z0oDC+0Mn7buPpOMhDP+M2Ik"

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: @password

  def user_fixture(attrs \\ %{}) do
    # TODO user with static password to speed up tests
    {:ok, user} =
      Repo.insert(
        %User{
          email: unique_user_email(),
          hashed_password: @hashed_password
        }
        |> Ecto.Changeset.change(attrs)
      )

    user |> Repo.preload(:authorized_scopes)
  end

  def user_scopes_fixture(user, attrs \\ %{}) do
    {:ok, scope} =
      Repo.insert(
        %UserAuthorizedScope{
          user_id: user.id,
          name: "name"
        }
        |> Ecto.Changeset.change(attrs)
      )

    scope
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.body, "[TOKEN]")
    token
  end
end
