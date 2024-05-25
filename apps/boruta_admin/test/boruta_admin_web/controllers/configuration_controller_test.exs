defmodule BorutaAdminWeb.ConfigurationControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  @update_error_template_attrs %{
    content: "some updated content"
  }
  @invalid_attrs %{content: nil}

  # TODO test sub restriction
  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(
             Routes.admin_configuration_error_template_path(
               conn,
               :error_template,
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
             Routes.admin_configuration_error_template_path(
               conn,
               :update_error_template,
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
             Routes.admin_configuration_error_template_path(
               conn,
               :delete_error_template,
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
             |> get(
               Routes.admin_configuration_error_template_path(
                 conn,
                 :error_template,
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
               Routes.admin_configuration_error_template_path(
                 conn,
                 :update_error_template,
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
               Routes.admin_configuration_error_template_path(
                 conn,
                 :delete_error_template,
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

  @tag :skip
  test "get an configuration template"

  describe "update configuration template" do
    @tag authorized: ["configuration:manage:all"]
    test "renders configuration when data is valid", %{
      conn: conn
    } do
      conn =
        patch(
          conn,
          Routes.admin_configuration_error_template_path(
            conn,
            :update_error_template,
            "400"
          ),
          template: @update_error_template_attrs
        )

      assert %{"id" => template_id, "content" => "some updated content"} =
               json_response(conn, 200)["data"]

      conn =
        get(
          conn,
          Routes.admin_configuration_error_template_path(
            conn,
            :error_template,
            "400"
          )
        )

      assert %{
               "id" => ^template_id,
               "content" => "some updated content",
               "type" => "400"
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["configuration:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        patch(
          conn,
          Routes.admin_configuration_error_template_path(conn, :update_error_template, "400"),
          template: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete error template" do
    @tag authorized: ["configuration:manage:all"]
    test "respond a 404 when error template does not exist", %{
      conn: conn
    } do
      type = "400"

      assert_error_sent(404, fn ->
        delete(
          conn,
          Routes.admin_configuration_error_template_path(
            conn,
            :delete_error_template,
            type
          )
        )
      end)
    end

    @tag authorized: ["configuration:manage:all"]
    test "deletes configuration template when template exists", %{
      conn: conn
    } do
      type = "400"
      insert(:error_template, type: type)

      conn =
        delete(
          conn,
          Routes.admin_configuration_error_template_path(
            conn,
            :delete_error_template,
            type
          )
        )

      assert %{"id" => nil, "type" => "400"} = json_response(conn, 200)["data"]
    end
  end

  describe "upsert configuration" do
    @tag authorized: ["configuration:manage:all", "clients:manage:all"]
    test "apply configuration file", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.admin_configuration_upload_configuration_file_path(
            conn,
            :upload_configuration_file
          ),
          %{
            "file" => %Plug.Upload{
              path:
                :code.priv_dir(:boruta_admin)
                |> Path.join("/test/configuration_files/bad_client_configuration.yml"),
              filename: "file.yml"
            },
            "options" => %{
              "hash_password" => "true"
            }
          }
        )

      assert json_response(conn, 200) == %{
               "errors" => %{"client" => [%{"identity_provider_id" => ["can't be blank"]}]},
               "file_content" =>
                 "---\nversion: \"1.0\"\nconfiguration:\n  client:\n    - access_token_ttl: 10\n"
             }
    end

    @tag authorized: ["configuration:manage:all"]
    test "does apply not authorized resources", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.admin_configuration_upload_configuration_file_path(
            conn,
            :upload_configuration_file
          ),
          %{
            "file" => %Plug.Upload{
              path:
                :code.priv_dir(:boruta_admin)
                |> Path.join("/test/configuration_files/bad_client_configuration.yml"),
              filename: "file.yml"
            },
            "options" => %{
              "hash_password" => "true"
            }
          }
        )

      assert json_response(conn, 200) == %{
               "errors" => %{},
               "file_content" =>
                 "---\nversion: \"1.0\"\nconfiguration:\n  client:\n    - access_token_ttl: 10\n"
             }
    end
  end
end
