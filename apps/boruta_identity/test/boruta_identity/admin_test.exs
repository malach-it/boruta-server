defmodule BorutaIdentity.AdminTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Admin
  alias BorutaIdentity.Repo

  describe "update_user_authorized_scopes/2" do
    test "returns an error on duplicates" do
      user = insert(:user)

      {:error, %Ecto.Changeset{} = changeset} =
        Admin.update_user_authorized_scopes(user, [%{"name" => "test"}, %{"name" => "test"}])

      assert changeset
    end

    test "stores user scopes" do
      user = insert(:user)

      {:ok,
       %User{
         authorized_scopes:
           [
             %UserAuthorizedScope{
               name: "test"
             }
           ]
       }} = Admin.update_user_authorized_scopes(user, [%{"name" => "test"}])

      assert [%{name: "test"}] = Repo.all(UserAuthorizedScope)
    end
  end

  describe "list_users/0" do
    test "returns an empty list" do
      assert Admin.list_users() == []
    end

    test "returns users" do
      user = insert(:user) |> Repo.preload(:authorized_scopes)
      assert Admin.list_users() == [user]
    end
  end

  describe "delete_user/1" do
    test "returns an error" do
      assert Admin.delete_user(Ecto.UUID.generate()) == {:error, :not_found}
    end

    test "returns deleted user" do
      %User{id: user_id} = insert(:user)
      assert {:ok, %User{id: ^user_id}} = Admin.delete_user(user_id)
      assert Repo.get(User, user_id) == nil
    end
  end
end
