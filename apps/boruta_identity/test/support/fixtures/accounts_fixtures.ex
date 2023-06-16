defmodule BorutaIdentity.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BorutaIdentity.Accounts` context.
  """

  import BorutaIdentity.Factory

  alias Boruta.Ecto.Admin
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Repo

  # From BorutaIdentity.Factory
  @password "hello world!"

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: @password

  def user_fixture(attrs \\ %{}) do
    backend = attrs[:backend] || insert(:backend)
    user = insert(:internal_user, Map.merge(%{backend: backend}, attrs))

    insert(:user,
      username: user.email,
      uid: user.id,
      backend: backend
    )
    |> Repo.preload([:authorized_scopes, :roles])
  end

  def user_scopes_fixture(user, attrs \\ %{}) do
    {:ok, scope} = Admin.create_scope(%{name: "name"})
    {:ok, scope} =
      Repo.insert(
        %UserAuthorizedScope{
          user_id: user.id,
          scope_id: scope.id
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
