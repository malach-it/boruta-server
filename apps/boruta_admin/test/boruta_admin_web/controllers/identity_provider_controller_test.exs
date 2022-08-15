defmodule BorutaAdminWeb.IdentityProviderControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @create_attrs %{
    name: "some name",
    type: "internal"
  }
  @update_attrs %{
    name: "some updated name"
  }
  @update_template_attrs %{
    content: "some updated content"
  }
  @invalid_attrs %{content: nil, type: "other"}

  def fixture(:identity_provider) do
    insert(:identity_provider, @create_attrs)
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_identity_provider_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_identity_provider_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_identity_provider_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_identity_provider_path(conn, :delete, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> get(
             Routes.admin_identity_provider_template_path(
               conn,
               :template,
               "identity_provider_id",
               "template_type"
             )
           )
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(
             Routes.admin_identity_provider_template_path(
               conn,
               :update_template,
               "identity_provider_id",
               "template_type"
             )
           )
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(
             Routes.admin_identity_provider_template_path(
               conn,
               :delete_template,
               "identity_provider_id",
               "template_type"
             )
           )
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
             |> get(Routes.admin_identity_provider_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_identity_provider_path(conn, :create))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_identity_provider_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_identity_provider_path(conn, :delete, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> get(
               Routes.admin_identity_provider_template_path(
                 conn,
                 :template,
                 "identity_provider_id",
                 "template_type"
               )
             )
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(
               Routes.admin_identity_provider_template_path(
                 conn,
                 :update_template,
                 "identity_provider_id",
                 "template_type"
               )
             )
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(
               Routes.admin_identity_provider_template_path(
                 conn,
                 :delete_template,
                 "identity_provider_id",
                 "template_type"
               )
             )
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
    test "lists all identity_providers", %{conn: conn} do
      conn = get(conn, Routes.admin_identity_provider_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_identity_provider_path(conn, :show, SecureRandom.uuid()))
      end
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders a identity provider", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: id} = identity_provider
    } do
      conn = get(conn, Routes.admin_identity_provider_path(conn, :show, identity_provider))
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end
  end

  describe "show template" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders not found", %{conn: conn, identity_provider: %IdentityProvider{id: id}} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_identity_provider_template_path(conn, :template, id, "unexisting"))
      end
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders a identity provider template", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: id}
    } do
      conn =
        get(
          conn,
          Routes.admin_identity_provider_template_path(conn, :template, id, "new_registration")
        )

      assert %{"identity_provider_id" => ^id, "type" => "new_registration"} =
               json_response(conn, 200)["data"]
    end
  end

  describe "create identity_provider" do
    @tag authorized: ["identity-providers:manage:all"]
    test "renders identity_provider when data is valid", %{conn: conn} do
      backend_id = insert(:backend).id

      conn =
        post(conn, Routes.admin_identity_provider_path(conn, :create),
          identity_provider: Map.put(@create_attrs, :backend_id, backend_id)
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.admin_identity_provider_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name",
               "type" => "internal",
               "backend" => %{"id" => ^backend_id}
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.admin_identity_provider_path(conn, :create),
          identity_provider: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  @tag :skip
  test "get an identity_provider template"

  describe "update identity_provider template" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders identity_provider when data is valid", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: identity_provider_id}
    } do
      conn =
        patch(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :update_template,
            identity_provider_id,
            "new_registration"
          ),
          template: @update_template_attrs
        )

      assert %{"id" => template_id, "content" => "some updated content"} =
               json_response(conn, 200)["data"]

      conn =
        get(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :template,
            identity_provider_id,
            "new_registration"
          )
        )

      assert %{
               "id" => ^template_id,
               "content" => "some updated content",
               "type" => "new_registration",
               "identity_provider_id" => ^identity_provider_id
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders errors when data is invalid", %{
      conn: conn,
      identity_provider: identity_provider
    } do
      conn =
        patch(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :update_template,
            identity_provider,
            "new_registration"
          ),
          template: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete identity_provider template" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "respond a 404 when identity provider does not exist", %{
      conn: conn
    } do
      identity_provider_id = SecureRandom.uuid()
      type = "new_registration"

      assert_error_sent(404, fn ->
        delete(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :delete_template,
            identity_provider_id,
            type
          )
        )
      end)
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "respond a 404 when template does not exist", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: identity_provider_id}
    } do
      type = "new_registration"

      assert_error_sent(404, fn ->
        delete(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :delete_template,
            identity_provider_id,
            type
          )
        )
      end)
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "deletes identity_provider template when template exists", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: identity_provider_id} = identity_provider
    } do
      type = "new_registration"
      insert(:template, type: type, identity_provider: identity_provider)

      conn =
        delete(
          conn,
          Routes.admin_identity_provider_template_path(
            conn,
            :delete_template,
            identity_provider_id,
            type
          )
        )

      assert %{"id" => nil, "type" => "new_registration"} = json_response(conn, 200)["data"]
    end
  end

  describe "update identity_provider" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "renders identity_provider when data is valid", %{
      conn: conn,
      identity_provider: %IdentityProvider{id: id} = identity_provider
    } do
      conn =
        put(conn, Routes.admin_identity_provider_path(conn, :update, identity_provider),
          identity_provider: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.admin_identity_provider_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "type" => "internal"
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "renders errors when data is invalid", %{
      conn: conn,
      identity_provider: identity_provider
    } do
      conn =
        put(conn, Routes.admin_identity_provider_path(conn, :update, identity_provider),
          identity_provider: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete identity_provider" do
    setup [:create_identity_provider]

    @tag authorized: ["identity-providers:manage:all"]
    test "cannot delete admin ui identity_provider", %{conn: conn} do
      client_identity_provider = insert(:client_identity_provider)
      current_admin_ui_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "")
      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client_identity_provider.client_id)

      conn =
        delete(
          conn,
          Routes.admin_identity_provider_path(
            conn,
            :delete,
            client_identity_provider.identity_provider
          )
        )

      assert response(conn, 403)

      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", current_admin_ui_client_id)
    end

    @tag authorized: ["identity-providers:manage:all"]
    test "deletes chosen identity_provider", %{conn: conn, identity_provider: identity_provider} do
      conn = delete(conn, Routes.admin_identity_provider_path(conn, :delete, identity_provider))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_identity_provider_path(conn, :show, identity_provider))
      end)
    end
  end

  defp create_identity_provider(_) do
    identity_provider = fixture(:identity_provider)
    %{identity_provider: identity_provider}
  end
end
