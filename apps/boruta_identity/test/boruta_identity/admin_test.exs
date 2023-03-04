defmodule BorutaIdentity.AdminTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.LdapError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Admin
  alias BorutaIdentity.Repo

  describe "update_user_authorized_scopes/2" do
    test "returns an error on duplicates" do
      user = insert(:user)

      assert {:error, %Ecto.Changeset{}} =
               Admin.update_user_authorized_scopes(user, [
                 %{"name" => "test"},
                 %{"name" => "test"}
               ])
    end

    test "stores user scopes" do
      scope = Boruta.Factory.insert(:scope, name: "test")
      user = insert(:user)

      user_id = user.id
      scope_id = scope.id

      {:ok,
       %User{
         authorized_scopes: [
           %UserAuthorizedScope{
             scope_id: ^scope_id,
             user_id: ^user_id
           }
         ]
       }} = Admin.update_user_authorized_scopes(user, [%{"id" => scope.id}])

      assert [%{scope_id: ^scope_id, user_id: ^user_id}] = Repo.all(UserAuthorizedScope)
    end
  end

  describe "list_users/0" do
    test "returns an empty list" do
      assert Admin.list_users() == %Scrivener.Page{
               entries: [],
               page_number: 1,
               page_size: 12,
               total_entries: 0,
               total_pages: 1
             }
    end

    test "returns paginated users" do
      user = insert(:user) |> Repo.preload(:authorized_scopes)

      assert Admin.list_users() == %Scrivener.Page{
               entries: [user],
               page_number: 1,
               page_size: 12,
               total_entries: 1,
               total_pages: 1
             }
    end
  end

  describe "search_users/0" do
    test "returns an empty search" do
      assert Admin.search_users("query") == %Scrivener.Page{
               entries: [],
               page_number: 1,
               page_size: 12,
               total_entries: 0,
               total_pages: 1
             }
    end

    test "returns user search" do
      _other = insert(:user) |> Repo.preload(:authorized_scopes)
      user = insert(:user, username: "match") |> Repo.preload(:authorized_scopes)

      assert Admin.search_users("match") == %Scrivener.Page{
               entries: [user],
               page_number: 1,
               page_size: 12,
               total_entries: 1,
               total_pages: 1
             }
    end
  end

  describe "delete_user/1 with internal backend" do
    test "returns an error" do
      assert Admin.delete_user(Ecto.UUID.generate()) == {:error, :not_found}
    end

    test "returns deleted user" do
      %User{id: user_id, uid: user_uid} = user_fixture()
      assert {:ok, %User{id: ^user_id}} = Admin.delete_user(user_id)
      refute Repo.get(User, user_id)
      refute Repo.get(Internal.User, user_uid)
    end
  end

  @tag :skip
  test "delete_user/1 with ldap backend"

  describe "create_user/2 with an internal backend" do
    setup do
      backend = insert(:backend)

      {:ok, backend: backend}
    end

    test "returns an error when data is invalid", %{backend: backend} do
      params = %{}

      assert {:error, %Ecto.Changeset{}} = Admin.create_user(backend, params)
    end

    test "creates a user", %{backend: backend} do
      params = %{username: "test@created.email", password: "a valid password"}

      assert {:ok, %User{}} = Admin.create_user(backend, params)
    end

    test "creates a user with metadata", %{backend: backend} do
      metadata_field = %{
        "attribute_name" => "attribute_test"
      }

      {:ok, backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [
            metadata_field
          ]
        })
        |> Repo.update()

      params = %{
        username: "test@created.email",
        password: "a valid password",
        metadata: %{"attribute_test" => "attribute_test value"}
      }

      assert {:ok,
              %User{
                metadata: %{"attribute_test" => "attribute_test value"}
              }} = Admin.create_user(backend, params)
    end

    test "creates a user with a group", %{backend: backend} do
      metadata_field = %{
        "attribute_name" => "attribute_test"
      }

      {:ok, backend} =
        Ecto.Changeset.change(backend, %{
          metadata_fields: [
            metadata_field
          ]
        })
        |> Repo.update()

      params = %{
        username: "test@created.email",
        password: "a valid password",
        group: "group"
      }

      assert {:ok,
              %User{
                group: "group"
              }} = Admin.create_user(backend, params)
    end
  end

  describe "create_user/2 with a ldap backend" do
    setup do
      backend = insert(:ldap_backend)

      {:ok, backend: backend}
    end

    test "raises an error", %{backend: backend} do
      params = %{}

      assert_raise LdapError, fn ->
        Admin.create_user(backend, params)
      end
    end

    @tag :skip
    test "creates a user"
  end

  describe "update_user/2 with an internal backend" do
    setup do
      user = user_fixture()

      {:ok, user: user}
    end

    test "updates user with metadata", %{user: user} do
      {:ok, _backend} =
        Ecto.Changeset.change(user.backend, %{metadata_fields: [%{attribute_name: "test"}]})
        |> Repo.update()

      metadata = %{"test" => "test value"}
      user_params = %{metadata: metadata}

      assert {:ok, %User{metadata: ^metadata}} = Admin.update_user(user, user_params)
    end

    test "returns an error if group is not unique", %{user: user} do
      {:ok, _backend} =
        Ecto.Changeset.change(user.backend, %{metadata_fields: [%{attribute_name: "test"}]})
        |> Repo.update()

      user_params = %{group: "group group"}

      assert {:error, %Ecto.Changeset{errors: [group: {"must be unique", []}]}} =
               Admin.update_user(user, user_params)
    end

    test "updates user with a group", %{user: user} do
      {:ok, _backend} =
        Ecto.Changeset.change(user.backend, %{metadata_fields: [%{attribute_name: "test"}]})
        |> Repo.update()

      user_params = %{group: "group"}

      assert {:ok, %User{group: "group"}} = Admin.update_user(user, user_params)
    end
  end

  @tag :skip
  test "create_raw_user/2"

  @tag :skip
  test "import_users/3"

  @tag :skip
  test "delete_user_authorized_scopes_by_id/1"
end
