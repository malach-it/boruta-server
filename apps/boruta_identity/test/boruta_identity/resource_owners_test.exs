defmodule BorutaIdentity.ResourceOwnersTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.ResourceOwner
  alias BorutaIdentity.Accounts.UserRole
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo
  alias BorutaIdentity.ResourceOwners

  doctest BorutaIdentity

  @valid_username unique_user_email()
  @valid_password valid_user_password()

  describe "get_by/1" do
    test "returns an user by username" do
      username = @valid_username

      user =
        user_fixture(%{
          email: username,
          password: @valid_password,
          backend: Backend.default!()
        })

      {:ok, result} = ResourceOwners.get_by(username: username)

      user_id = user.id

      assert %ResourceOwner{sub: ^user_id, username: ^username, extra_claims: %{user: _user}} =
               result
    end

    test "returns an user by sub" do
      user =
        user_fixture(%{
          email: @valid_username,
          password: @valid_password,
          backend: Backend.default!()
        })

      {:ok, result} = ResourceOwners.get_by(sub: user.id)
      assert result == %ResourceOwner{sub: user.id, username: user.username}
    end

    test "returns nil when username do not exists" do
      user_fixture(%{
        email: @valid_username,
        password: @valid_password,
        backend: Backend.default!()
      })

      assert ResourceOwners.get_by(username: "other") == {:error, "Invalid username or password."}
    end
  end

  describe "#check_password/2" do
    test "returns ok if password match" do
      username = @valid_username
      backend = Backend.default!()

      user =
        user_fixture(%{
          email: username,
          password: @valid_password,
          backend: backend
        })

      {:ok, impl_user} =
        apply(Backend.implementation(backend), :get_user, [backend, %{email: username}])

      resource_owner = %ResourceOwner{
        sub: user.id,
        username: user.username,
        extra_claims: %{user: impl_user}
      }

      assert ResourceOwners.check_password(resource_owner, @valid_password) == :ok
    end

    test "returns an error if password do not match" do
      user =
        user_fixture(%{
          email: @valid_username,
          password: @valid_password,
          backend: Backend.default!()
        })

      resource_owner = %ResourceOwner{sub: user.id}

      assert ResourceOwners.check_password(resource_owner, "wrong password") ==
               {:error, "Invalid username or password."}
    end
  end

  describe "authorized_scopes/1" do
    test "returns an empty array" do
      user = user_fixture(%{backend: Backend.default!()})
      resource_owner = %ResourceOwner{sub: user.id}
      assert ResourceOwners.authorized_scopes(resource_owner) == []
    end

    test "return user associated scopes with authorized scopes" do
      %{id: id} = user = user_fixture(%{backend: Backend.default!()})
      {:ok, scope} = Admin.create_scope(%{name: "scope:scope"})
      insert(:user_authorized_scope, user_id: id, scope_id: scope.id)

      resource_owner = %ResourceOwner{sub: user.id}

      name = scope.name
      assert [%Boruta.Oauth.Scope{name: ^name}] = ResourceOwners.authorized_scopes(resource_owner)
    end

    test "return user associated scopes with roles" do
      %{id: id} = user = user_fixture(%{backend: Backend.default!()})
      {:ok, scope} = Admin.create_scope(%{name: "scope:scope"})
      role = insert(:role)
      insert(:role_scope, role_id: role.id, scope_id: scope.id)
      insert(:user_role, user_id: id, role_id: role.id)

      resource_owner = %ResourceOwner{sub: user.id}

      name = scope.name
      assert [%Boruta.Oauth.Scope{name: ^name}] = ResourceOwners.authorized_scopes(resource_owner)
    end
  end

  describe "claims/2" do
    test "returns user metadata" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [%{"attribute_name" => "metadata"}]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"metadata" => true}}) |> Repo.update()

      assert %{"metadata" => true} = ResourceOwners.claims(%ResourceOwner{sub: user.id}, "")
    end

    test "returns user roles" do
      user = user_fixture()
      role = BorutaIdentity.Factory.insert(:role)

      Repo.insert(%UserRole{user_id: user.id, role_id: role.id})

      role_name = role.name
      assert %{"roles" => [^role_name]} = ResourceOwners.claims(%ResourceOwner{sub: user.id}, "")
    end

    test "filters user metadata" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [%{"attribute_name" => "metadata"}]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"filtered" => true, "metadata" => true}})
        |> Repo.update()

      assert %{"metadata" => true} = ResourceOwners.claims(%ResourceOwner{sub: user.id}, "")
    end

    test "filters user metadata according to scopes" do
      user = user_fixture()

      {:ok, backend} =
        Ecto.Changeset.change(user.backend, %{
          metadata_fields: [
            %{"attribute_name" => "without_scopes"},
            %{"attribute_name" => "test_scope", "scopes" => ["test"]},
            %{"attribute_name" => "other_scope", "scopes"=> ["other"]}
          ]
        })
        |> Repo.update()

      user = %{user | backend: backend}

      {:ok, user} =
        Ecto.Changeset.change(user, %{metadata: %{"without_scopes" => true, "test_scope" => true, "other_scope" => true}})
        |> Repo.update()

      assert %{"without_scopes" => true, "test_scope" => true} = ResourceOwners.claims(%ResourceOwner{sub: user.id}, "test")
    end
  end
end
