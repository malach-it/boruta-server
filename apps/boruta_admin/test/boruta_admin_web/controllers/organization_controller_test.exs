defmodule BorutaAdminWeb.OrganizationControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.Organizations.Organization
  alias BorutaIdentity.Repo

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_organization_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_organization_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_organization_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_organization_path(conn, :delete, "id"))
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
             |> get(Routes.admin_organization_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_organization_path(conn, :create))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_organization_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_organization_path(conn, :delete, "id"))
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
    test "lists all organizations", %{conn: conn} do
      conn = get(conn, Routes.admin_organization_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create organization" do
    @tag authorized: ["users:manage:all"]
    test "renders bad request", %{
      conn: conn
    } do
      conn = post(conn, Routes.admin_organization_path(conn, :create), %{})

      assert json_response(conn, 400)
    end

    @tag authorized: ["users:manage:all"]
    test "renders an error when data is invalid", %{
      conn: conn
    } do
      name = nil

      conn =
        post(conn, Routes.admin_organization_path(conn, :create), %{
          "organization" => %{
            "name" => name
          }
        })

      assert json_response(conn, 422) == %{
               "code" => "UNPROCESSABLE_ENTITY",
               "errors" => %{"name" => ["can't be blank"]},
               "message" => "Your request could not be processed."
             }
    end

    @tag authorized: ["users:manage:all"]
    test "renders organization when data is valid", %{
      conn: conn
    } do
      name = "Organization name"

      conn =
        post(conn, Routes.admin_organization_path(conn, :create), %{
          "organization" => %{
            "name" => name
          }
        })

      assert %{"id" => _id, "name" => ^name} = json_response(conn, 200)["data"]
    end
  end

  describe "update organization" do
    setup do
      organization = insert(:organization)

      {:ok, organization: organization}
    end

    @tag authorized: ["users:manage:all"]
    test "renders an error when bad request", %{
      conn: conn,
      organization: organization
    } do
      conn = put(conn, Routes.admin_organization_path(conn, :update, organization), %{})

      assert json_response(conn, 400)
    end

    @tag authorized: ["users:manage:all"]
    test "updates organization with metadata", %{
      conn: conn,
      organization: %Organization{id: id} = organization
    } do
      name = "Organization name"

      conn =
        put(conn, Routes.admin_organization_path(conn, :update, organization),
          organization: %{
            "name" => name
          }
        )

      assert %{"id" => ^id, "name" => ^name} = json_response(conn, 200)["data"]

      assert %Organization{name: ^name} = Repo.get!(Organization, id)
    end
  end

  describe "delete organization" do
    @tag authorized: ["users:manage:all"]
    test "returns a 404", %{conn: conn} do
      organization_id = SecureRandom.uuid()

      conn = delete(conn, Routes.admin_organization_path(conn, :delete, organization_id))

      assert response(conn, 404)
    end

    @tag authorized: ["users:manage:all"]
    test "deletes the organization", %{conn: conn} do
      %Organization{id: organization_id} = insert(:organization)

      conn = delete(conn, Routes.admin_organization_path(conn, :delete, organization_id))

      assert response(conn, 204)
      refute BorutaIdentity.Repo.get(Organization, organization_id)
    end
  end
end
