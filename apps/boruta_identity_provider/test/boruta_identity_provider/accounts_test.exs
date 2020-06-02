defmodule BorutaIdentityProvider.AccountsTest do
  import BorutaIdentityProvider.Factory

  use BorutaIdentityProvider.DataCase

  alias BorutaIdentityProvider.Accounts
  alias BorutaIdentityProvider.Accounts.User

  describe "list_users/0" do
    test "returns an empty array" do
      assert Accounts.list_users() == []
    end

    test "returns database users" do
      user = %{insert(:user)|password: nil, authorized_scopes: []}

      assert Accounts.list_users() |> Repo.preload(:authorized_scopes) == [user]
    end
   end

  describe "get_user!/1" do
    test "throws an error" do
      try do
        Accounts.get_user!(SecureRandom.uuid)
      rescue
        _ in Ecto.NoResultsError -> assert true
      end
    end

    test "returns user given an id" do
      %User{id: id} = user = %{insert(:user)|password: nil, authorized_scopes: []}

      assert Accounts.get_user!(id) |> Repo.preload(:authorized_scopes) == user
    end
  end

  describe "check_password/2" do
    test "returns ok if password is valid" do
      %User{password: password} = user = insert(:user)

      assert Accounts.check_password(user, password) == :ok
    end

    test "returns error if password is invalid" do
      user = insert(:user)

      assert Accounts.check_password(user, "invalid password") == {:error, "Invalid password"}
    end
  end

  describe "get_user_by/1" do
    test "returns nil" do
      assert Accounts.get_user_by(id: SecureRandom.uuid) == nil
    end

    test "returns user given an id" do
      %User{id: id} = user = %{insert(:user)|password: nil, authorized_scopes: []}

      assert Accounts.get_user_by(id: id) |> Repo.preload(:authorized_scopes) == user
    end
  end

  describe "update_user/2" do
    test "updates a user email" do
      user = %{insert(:user)|password: nil, authorized_scopes: []}
      updated_email = "updated@email"

      {:ok, updated_user} = Accounts.update_user(user, %{email: updated_email})
      updated_user = updated_user
      |> Repo.preload(:authorized_scopes)

      assert updated_user == %{user|email: updated_email}
    end

    test "updates a user scopes" do
      scope = Boruta.Factory.insert(:scope)

      authorized_scopes = Enum.map([scope], fn (%{id: id}) ->
        %{"id" => id}
      end)
      user = %{insert(:user)|password: nil, authorized_scopes: []}

      {:ok, updated_user} = Accounts.update_user(user, %{"authorized_scopes" => authorized_scopes})
      updated_user = updated_user
      |> Repo.preload(:authorized_scopes)

      scope_id = scope.id
      case updated_user do
        %{authorized_scopes: [
          %{scope_id: ^scope_id}
        ]} -> assert true
        _ -> assert false
      end
    end
  end
end
