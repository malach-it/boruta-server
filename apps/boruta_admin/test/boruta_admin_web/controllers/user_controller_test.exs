defmodule BorutaAdminWeb.UserControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_user_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_user_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_user_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_user_path(conn, :delete, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_user_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_user_path(conn, :create))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_user_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_user_path(conn, :delete, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["users:manage:all"]
    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create user" do
    @tag authorized: ["users:manage:all"]
    test "renders bad request", %{
      conn: conn
    } do
      conn = post(conn, Routes.admin_user_path(conn, :create), %{})

      assert json_response(conn, 400)
    end

    @tag authorized: ["users:manage:all"]
    test "renders an error when data is invalid", %{
      conn: conn
    } do
      email = unique_user_email()

      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "provider" => "Elixir.BorutaIdentity.Accounts.Internal",
          "user" => %{
            "email" => email
          }
        })

      assert json_response(conn, 422) == %{
               "code" => "UNPROCESSABLE_ENTITY",
               "errors" => %{"password" => ["can't be blank"]},
               "message" => "Your request could not be processed."
             }
    end

    @tag authorized: ["users:manage:all"]
    test "renders user when data is valid", %{
      conn: conn
    } do
      email = unique_user_email()

      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "provider" => "Elixir.BorutaIdentity.Accounts.Internal",
          "user" => %{
            "email" => email,
            "password" => valid_user_password()
          }
        })

      assert %{"id" => _id, "email" => ^email} = json_response(conn, 200)["data"]
    end
  end

  describe "update user" do
    setup %{conn: conn} do
      user = user_fixture()
      scope = Boruta.Factory.insert(:scope)

      {:ok, conn: conn, user: user, existing_scope: scope}
    end

    @tag authorized: ["users:manage:all"]
    test "renders an error when bad request", %{
      conn: conn,
      user: user
    } do
      conn = put(conn, Routes.admin_user_path(conn, :update, user), %{})

      assert json_response(conn, 400)
    end

    @tag authorized: ["users:manage:all"]
    test "renders user when data is valid", %{
      conn: conn,
      user: %User{id: id} = user,
      existing_scope: scope
    } do
      conn =
        put(conn, Routes.admin_user_path(conn, :update, user),
          user: %{
            "authorized_scopes" => [%{"id" => scope.id}]
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag user_authorized: ["users:manage:all"]
    test "cannot update current user", %{
      conn: conn,
      existing_scope: scope,
      resource_owner: resource_owner
    } do
      conn =
        put(conn, Routes.admin_user_path(conn, :update, resource_owner.sub),
          user: %{
            "authorized_scopes" => [%{"name" => scope.name}]
          }
        )

      assert response(conn, 403)
    end
  end

  describe "delete" do
    @tag authorized: ["users:manage:all"]
    test "returns a 404", %{conn: conn} do
      user_id = SecureRandom.uuid()

      conn = delete(conn, Routes.admin_user_path(conn, :delete, user_id))

      assert response(conn, 404)
    end

    @tag authorized: ["users:manage:all"]
    test "deletes the user", %{conn: conn} do
      %{id: user_id, uid: user_uid} = user_fixture()

      conn = delete(conn, Routes.admin_user_path(conn, :delete, user_id))

      assert response(conn, 204)
      refute BorutaIdentity.Repo.get(User, user_id)
      refute BorutaIdentity.Repo.get(Internal.User, user_uid)
    end

    @tag user_authorized: ["users:manage:all"]
    test "cannot delete current user", %{conn: conn, resource_owner: resource_owner} do
      conn = delete(conn, Routes.admin_user_path(conn, :delete, resource_owner.sub))

      assert response(conn, 403)
    end
  end
end
