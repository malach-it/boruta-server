defmodule BorutaIdentityProvider.ResourceOwnersTest do
  use BorutaWeb.DataCase

  import BorutaIdentityProvider.Factory

  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentityProvider.Accounts.HashSalt
  alias BorutaWeb.ResourceOwners

  doctest BorutaIdentityProvider

  test "greets the world" do
    assert true
  end

  describe "get_by/1" do
    test "returns an user by username" do
      username = "username"
      password = "password"
      user = insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      {:ok, result} = ResourceOwners.get_by(username: username)
      assert result == %ResourceOwner{sub: user.id, username: user.email}
    end

    test "returns an user by sub" do
      username = "username"
      password = "password"
      user = insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      {:ok, result} = ResourceOwners.get_by(sub: user.id)
      assert result == %ResourceOwner{sub: user.id, username: user.email}
    end

    test "returns nil when username do not exists" do
      username = "username"
      password = "password"
      insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      assert ResourceOwners.get_by(username: "other") == {:error, "User not found."}
    end
  end

  describe "#check_password/2" do
    test "returns ok if password match" do
      username = "username"
      password = "password"
      user = insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.check_password(resource_owner, password) == :ok
    end

    test "returns an error if password do not match" do
      username = "username"
      password = "password"
      user = insert(:user, email: username, password_hash: HashSalt.hashpwsalt(password))

      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.check_password(resource_owner, "wrong password") == {:error, "Invalid password."}
    end
  end

  describe "authorized_scopes/1" do
    test "returns an empty array" do
      user = insert(:user)

      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.authorized_scopes(resource_owner) == []
    end

    test "return user associated scopes" do
      %{id: id} = user = insert(:user)
      scope = Boruta.Factory.insert(:scope)
      insert(:user_scope, user_id: id, name: scope.name)

      resource_owner = %ResourceOwner{sub: user.id}
      case ResourceOwners.authorized_scopes(resource_owner) do
        [%Boruta.Oauth.Scope{name: name}] ->
          assert name == scope.name
          _ -> assert false
      end
    end
  end
end
