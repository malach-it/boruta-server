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

      assert Accounts.list_users() == [user]
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

      assert Accounts.get_user!(id) == user
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

      assert Accounts.get_user_by(id: id) == user
    end
  end

  describe "update_user/2" do
    test "updates a user email" do
      user = %{insert(:user)|password: nil, authorized_scopes: []}
      updated_email = "updated@email"

      {:ok, updated_user} = Accounts.update_user(user, %{email: updated_email})

      assert updated_user == %{user|email: updated_email}
    end

    test "updates a user scopes" do
      scopes = [
        Boruta.Factory.insert(:scope),
        Boruta.Factory.insert(:scope)
      ]
      authorized_scopes = Enum.map(scopes, fn (%{id: id}) -> 
        %{"id" => id}
      end)
      oauth_scopes = Enum.map(scopes, fn (%{id: id, name: name, public: public}) -> 
        %Boruta.Oauth.Scope{id: id, name: name, public: public}
      end)
      user = %{insert(:user)|password: nil, authorized_scopes: []}

      {:ok, updated_user} = Accounts.update_user(user, %{"authorized_scopes" => authorized_scopes})

      assert updated_user == %{user|authorized_scopes: oauth_scopes}
    end

    test "updates a user scopes without unexisting scopes" do
      scopes = [
        Boruta.Factory.insert(:scope)
      ]
      authorized_scopes = Enum.map(scopes, fn (%{id: id}) -> 
        %{"id" => id}
      end)
      authorized_scopes = [%{"id" => SecureRandom.uuid}|authorized_scopes]
      oauth_scopes = Enum.map(scopes, fn (%{id: id, name: name, public: public}) -> 
        %Boruta.Oauth.Scope{id: id, name: name, public: public}
      end)
      user = %{insert(:user)|password: nil, authorized_scopes: []}

      {:ok, updated_user} = Accounts.update_user(user, %{"authorized_scopes" => authorized_scopes})

      assert updated_user == %{user|authorized_scopes: oauth_scopes}
    end
  end
end