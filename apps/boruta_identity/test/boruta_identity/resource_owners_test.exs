defmodule BorutaIdentity.ResourceOwnersTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures

  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentity.ResourceOwners

  doctest BorutaIdentity

  @valid_username unique_user_email()
  @valid_password valid_user_password()

  describe "get_by/1" do
    test "returns an user by username" do
      user = user_fixture(email: @valid_username, password: @valid_password)

      {:ok, result} = ResourceOwners.get_by(username: @valid_username)
      assert result == %ResourceOwner{sub: user.id, username: user.username}
    end

    test "returns an user by sub" do
      user = user_fixture(email: @valid_username, password: @valid_password)

      {:ok, result} = ResourceOwners.get_by(sub: user.id)
      assert result == %ResourceOwner{sub: user.id, username: user.username}
    end

    test "returns nil when username do not exists" do
      user_fixture(email: @valid_username, password: @valid_password)

      assert ResourceOwners.get_by(username: "other") == {:error, "User not found."}
    end
  end

  describe "#check_password/2" do
    test "returns ok if password match" do
      user = user_fixture(email: @valid_username, password: @valid_password)

      resource_owner = %ResourceOwner{sub: user.id, username: user.username}
      assert ResourceOwners.check_password(resource_owner, @valid_password) == :ok
    end

    test "returns an error if password do not match" do
      user = user_fixture(email: @valid_username, password: @valid_password)

      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.check_password(resource_owner, "wrong password") == {:error, "Invalid password."}
    end
  end

  describe "authorized_scopes/1" do
    test "returns an empty array" do
      user = user_fixture()
      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.authorized_scopes(resource_owner) == []
    end

    @tag :skip
    test "return user associated scopes" do
      %{id: _id} = user = user_fixture()
      scope = Boruta.Factory.insert(:scope)
      # insert(:user_scope, user_id: id, name: scope.name)

      resource_owner = %ResourceOwner{sub: user.id}
      case ResourceOwners.authorized_scopes(resource_owner) do
        [%Boruta.Oauth.Scope{name: name}] ->
          assert name == scope.name
          _ -> assert false
      end
    end
  end
end
