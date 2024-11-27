defmodule BorutaAdminWeb.UserControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  alias Boruta.Ecto.Admin
  alias BorutaIdentity.Accounts.Internal
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # TODO test sub restriction
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
    setup %{conn: conn} do
      {:ok, scope} = Admin.create_scope(%{name: "some:scope"})
      role = insert(:role)
      organization = insert(:organization)
      insert(:role_scope, role_id: role.id, scope_id: scope.id)

      {:ok,
       conn: conn, existing_scope: scope, existing_role: role, existing_organization: organization}
    end

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
          "backend_id" => insert(:backend).id,
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
          "backend_id" => insert(:backend).id,
          "user" => %{
            "email" => email,
            "password" => valid_user_password()
          }
        })

      assert %{"id" => _id, "email" => ^email} = json_response(conn, 200)["data"]
    end

    @tag authorized: ["users:manage:all"]
    test "creates user with authorized scopes", %{
      conn: conn,
      existing_scope: scope
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "user" => %{
            "email" => unique_user_email(),
            "password" => valid_user_password(),
            "authorized_scopes" => [%{"id" => scope.id}]
          }
        })

      scope_id = scope.id

      assert %{"id" => _id, "authorized_scopes" => [%{"id" => ^scope_id}]} =
               json_response(conn, 200)["data"]
    end

    @tag authorized: ["users:manage:all"]
    test "creates user with organizations", %{
      conn: conn,
      existing_organization: organization
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "user" => %{
            "email" => unique_user_email(),
            "password" => valid_user_password(),
            "organizations" => [%{"id" => organization.id}]
          }
        })

      organization_id = organization.id

      assert %{"id" => _id, "organizations" => [%{"id" => ^organization_id}]} =
               json_response(conn, 200)["data"]
    end

    @tag authorized: ["users:manage:all"]
    test "creates user with roles", %{
      conn: conn,
      existing_scope: scope,
      existing_role: role
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "user" => %{
            "email" => unique_user_email(),
            "password" => valid_user_password(),
            "roles" => [%{"id" => role.id}]
          }
        })

      scope_id = scope.id
      role_id = role.id

      assert %{"id" => _id, "roles" => [%{"id" => ^role_id, "scopes" => [%{"id" => ^scope_id}]}]} =
               json_response(conn, 200)["data"]
    end
  end

  describe "import users" do
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
          "backend_id" => insert(:backend).id,
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
    test "renders import result when data is valid", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "file" => %Plug.Upload{
            path: Path.join(__DIR__, "./../../data/import_users_password_valid.csv"),
            filename: "users.csv"
          },
          "options" => %{
            "hash_password" => "true"
          }
        })

      assert json_response(conn, 200) == %{
               "error_count" => 0,
               "errors" => [],
               "success_count" => 2
             }

      assert Repo.all(Internal.User) |> Enum.count() == 2
    end

    @tag authorized: ["users:manage:all"]
    test "renders import result when data is valid with custom headers", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "file" => %Plug.Upload{
            path:
              Path.join(__DIR__, "./../../data/import_users_password_custom_headers_valid.csv"),
            filename: "users.csv"
          },
          "options" => %{
            "hash_password" => "true",
            "username_header" => "username_header",
            "password_header" => "password_header"
          }
        })

      assert json_response(conn, 200) == %{
               "error_count" => 0,
               "errors" => [],
               "success_count" => 2
             }

      assert Repo.all(Internal.User) |> Enum.count() == 2
    end

    @tag authorized: ["users:manage:all"]
    test "renders import result users when data is invalid", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "file" => %Plug.Upload{
            path: Path.join(__DIR__, "./../../data/import_users_password_invalid.csv"),
            filename: "users.csv"
          },
          "options" => %{
            "hash_password" => "true"
          }
        })

      assert json_response(conn, 200) == %{
               "error_count" => 3,
               "errors" => [
                 %{
                   "changeset" => %{"password" => ["should be at least 12 character(s)"]},
                   "line" => 1
                 },
                 %{
                   "changeset" => %{
                     "email" => ["can't be blank"],
                     "password" => ["should be at least 12 character(s)"]
                   },
                   "line" => 2
                 },
                 %{"changeset" => %{"email" => ["can't be blank"]}, "line" => 3}
               ],
               "success_count" => 1
             }

      assert Repo.all(Internal.User) |> Enum.count() == 1
    end

    @tag authorized: ["users:manage:all"]
    test "renders import result users when data is valid with hashed password", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.admin_user_path(conn, :create), %{
          "backend_id" => insert(:backend).id,
          "file" => %Plug.Upload{
            path: Path.join(__DIR__, "./../../data/import_users_hashed_password_valid.csv"),
            filename: "users.csv"
          },
          "options" => %{
            "hash_password" => false
          }
        })

      assert json_response(conn, 200) == %{
               "error_count" => 0,
               "errors" => [],
               "success_count" => 2
             }

      assert Repo.all(Internal.User) |> Enum.count() == 2
    end
  end

  describe "update user" do
    setup %{conn: conn} do
      user = user_fixture()
      {:ok, scope} = Admin.create_scope(%{name: "some:scope"})
      role = insert(:role)
      insert(:role_scope, role_id: role.id, scope_id: scope.id)

      {:ok, conn: conn, user: user, existing_scope: scope, existing_role: role}
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
    test "updates user with metadata", %{
      conn: conn,
      user: %User{id: id} = user
    } do
      {:ok, _backend} =
        Ecto.Changeset.change(user.backend, %{metadata_fields: [%{attribute_name: "test"}]})
        |> Repo.update()

      metadata = %{"test" => %{"value" => "test value", "status" => "valid", "display" => []}}

      conn =
        put(conn, Routes.admin_user_path(conn, :update, user),
          user: %{
            "metadata" => metadata
          }
        )

      assert %{
               "id" => ^id,
               "metadata" => %{
                 "test" => %{"value" => "test value", "status" => "valid", "display" => []}
               }
             } = json_response(conn, 200)["data"]

      assert %User{metadata: ^metadata} = Repo.get!(User, id)
    end

    @tag authorized: ["users:manage:all"]
    test "updates user with group", %{
      conn: conn,
      user: %User{id: id} = user
    } do
      group = "group1 group2"

      conn =
        put(conn, Routes.admin_user_path(conn, :update, user),
          user: %{
            "group" => group
          }
        )

      assert %{"id" => ^id, "group" => ^group} = json_response(conn, 200)["data"]
      assert %User{group: ^group} = Repo.get!(User, id)
    end

    @tag authorized: ["users:manage:all"]
    test "updates user with authorized scopes", %{
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

    @tag authorized: ["users:manage:all"]
    test "updates user with roles", %{
      conn: conn,
      user: %User{id: id} = user,
      existing_scope: scope,
      existing_role: role
    } do
      conn =
        put(conn, Routes.admin_user_path(conn, :update, user),
          user: %{
            "roles" => [%{"id" => role.id}]
          }
        )

      scope_id = scope.id
      role_id = role.id

      assert %{"id" => ^id, "roles" => [%{"id" => ^role_id, "scopes" => [%{"id" => ^scope_id}]}]} =
               json_response(conn, 200)["data"]
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
