defmodule BorutaAdminWeb.BackendControllerTest do
  use BorutaAdminWeb.ConnCase

  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil, type: "other"}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_backend_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> get(Routes.admin_backend_path(conn, :show, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_backend_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_backend_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_backend_path(conn, :delete, "id"))
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
             |> get(Routes.admin_backend_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> get(Routes.admin_backend_path(conn, :show, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_backend_path(conn, :create))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_backend_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_backend_path(conn, :delete, "id"))
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
    @tag authorized: ["identity-providers:manage:all"]
    test "lists all backends", %{conn: conn} do
      conn = get(conn, Routes.admin_backend_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show" do
    setup [:create_backend]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_backend_path(conn, :show, "unexisting"))
      end
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "shows a backend", %{conn: conn, backend: backend} do
      conn = get(conn, Routes.admin_backend_path(conn, :show, backend))

      name = backend.name

      assert %{
               "id" => _id,
               "name" => ^name,
               "type" => "Elixir.BorutaIdentity.Accounts.Internal"
             } = json_response(conn, 200)["data"]
    end
  end

  describe "create" do
    @tag authorized: ["identity-providers:manage:all"]
    test "renders a bad request", %{conn: conn} do
      conn = post(conn, Routes.admin_backend_path(conn, :create), %{})

      assert json_response(conn, 400) == %{
               "code" => "BAD_REQUEST",
               "errors" => %{
                 "resource" => ["the requested with given parameters cannot be processed."]
               },
               "message" => "The requested with given parameters cannot be processed."
             }
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders an error when params are invalid", %{conn: conn} do
      conn =
        post(conn, Routes.admin_backend_path(conn, :create), %{
          "backend" => @invalid_attrs
        })

      assert json_response(conn, 422) == %{
               "code" => "UNPROCESSABLE_ENTITY",
               "errors" => %{"name" => ["can't be blank"], "type" => ["is invalid"]},
               "message" => "Your request could not be processed."
             }
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "creates a backend", %{conn: conn} do
      conn =
        post(conn, Routes.admin_backend_path(conn, :create), %{"backend" => @create_attrs})

      assert %{
               "id" => _id,
               "name" => "some name",
               "type" => "Elixir.BorutaIdentity.Accounts.Internal"
             } = json_response(conn, 201)["data"]
    end
  end

  describe "update" do
    setup [:create_backend]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        patch(conn, Routes.admin_backend_path(conn, :update, "unexisting"), %{"backend" => %{}})
      end
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders a bad request", %{conn: conn} do
      conn = patch(conn, Routes.admin_backend_path(conn, :update, "id"), %{})

      assert json_response(conn, 400) == %{
               "code" => "BAD_REQUEST",
               "errors" => %{
                 "resource" => ["the requested with given parameters cannot be processed."]
               },
               "message" => "The requested with given parameters cannot be processed."
             }
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders an error when params are invalid", %{conn: conn, backend: backend} do
      conn =
        patch(conn, Routes.admin_backend_path(conn, :update, backend), %{
          "backend" => @invalid_attrs
        })

      assert json_response(conn, 422) == %{
               "code" => "UNPROCESSABLE_ENTITY",
               "errors" => %{"name" => ["can't be blank"], "type" => ["is invalid"]},
               "message" => "Your request could not be processed."
             }
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "updates a backend", %{conn: conn, backend: backend} do
      conn =
        patch(conn, Routes.admin_backend_path(conn, :update, backend), %{"backend" => @update_attrs})

      assert %{
               "id" => _id,
               "name" => "some updated name",
               "type" => "Elixir.BorutaIdentity.Accounts.Internal"
             } = json_response(conn, 200)["data"]
    end
  end

  describe "delete" do
    setup [:create_backend]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_backend_path(conn, :show, "unexisting"))
      end
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "deletes a backend", %{conn: conn, backend: backend} do
      conn = delete(conn, Routes.admin_backend_path(conn, :delete, backend))

      assert response(conn, 204)

      refute Repo.get(Backend, backend.id)
    end
  end

  def fixture(:backend) do
    {:ok, backend} = IdentityProviders.create_backend(@create_attrs)
    backend
  end

  defp create_backend(_) do
    backend = fixture(:backend)
    %{backend: backend}
  end
end
