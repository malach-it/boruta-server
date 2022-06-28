defmodule BorutaAdminWeb.ConfigurationControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  @update_error_template_attrs %{
    content: "some updated content"
  }
  @invalid_attrs %{content: nil}

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
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
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
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
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
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
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
        patch(conn, Routes.admin_configuration_error_template_path(conn, :update_error_template, "400"),
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

      assert %{"id" => nil, "type" => "400"} =
               json_response(conn, 200)["data"]
    end
  end
end
