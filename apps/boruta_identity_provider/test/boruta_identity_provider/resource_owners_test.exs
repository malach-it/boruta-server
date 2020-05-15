defmodule BorutaIdentityProvider.ResourceOwnersTest do
  use BorutaIdentityProvider.DataCase

  import BorutaIdentityProvider.Factory

  alias BorutaIdentityProvider.Accounts
  alias BorutaIdentityProvider.Accounts.HashSalt
  alias BorutaIdentityProvider.Accounts.User
  alias BorutaIdentityProvider.ResourceOwners

  doctest BorutaIdentityProvider

  test "greets the world" do
    assert true
  end

  describe "get_by/1" do
    test "returns an user by id" do
      %User{id: id} = user = insert(:user)

      assert %{ResourceOwners.get_by(id: id)|password: user.password} == %{user|authorized_scopes: []}
    end

    test "returns nil if not exists" do
      id = SecureRandom.uuid

      assert ResourceOwners.get_by(id: id) == nil
    end

    test "returns an user by username and password" do
      username = "username"
      password = "password"
      user = insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      assert %{ResourceOwners.get_by(username: username, password: password)|password: user.password} == %{user|authorized_scopes: []}
    end

    test "returns nil when username do not exists" do
      username = "username"
      password = "password"
      insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      assert ResourceOwners.get_by(username: "other", password: password) == nil
    end

    test "returns nil when password is wrong" do
      username = "username"
      password = "password"
      insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      assert ResourceOwners.get_by(username: username, password: "wrong") == nil
    end
  end

  describe "authorized_scopes/1" do
    test "returns an empty array" do
      user = insert(:user)

      assert ResourceOwners.authorized_scopes(user) == []
    end

    test "return user associated scopes" do
      %{id: id} = insert(:user)
      scope = Boruta.Factory.insert(:scope)
      insert(:user_scope, user_id: id, scope_id: scope.id)
      user = Accounts.get_user_by(id: id)

      assert ResourceOwners.authorized_scopes(user) == [%Boruta.Oauth.Scope{id: scope.id, name: scope.name, public: scope.public}]
    end
  end
end
