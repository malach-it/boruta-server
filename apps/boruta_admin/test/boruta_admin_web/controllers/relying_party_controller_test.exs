defmodule BorutaAdminWeb.RelyingPartyControllerTest do
  use BorutaAdminWeb.ConnCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

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
  @invalid_attrs %{name: nil, type: "other"}

  def fixture(:relying_party) do
    {:ok, relying_party} = RelyingParties.create_relying_party(@create_attrs)
    relying_party
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get(Routes.admin_relying_party_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> post(Routes.admin_relying_party_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> patch(Routes.admin_relying_party_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> delete(Routes.admin_relying_party_path(conn, :delete, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> get(
             Routes.admin_relying_party_template_path(
               conn,
               :template,
               "relying_party_id",
               "template_type"
             )
           )
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> patch(
             Routes.admin_relying_party_template_path(
               conn,
               :update_template,
               "relying_party_id",
               "template_type"
             )
           )
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }

    assert conn
           |> delete(
             Routes.admin_relying_party_template_path(
               conn,
               :delete_template,
               "relying_party_id",
               "template_type"
             )
           )
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource."
           }
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_relying_party_path(conn, :index))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> post(Routes.admin_relying_party_path(conn, :create))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> patch(Routes.admin_relying_party_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> delete(Routes.admin_relying_party_path(conn, :delete, "id"))
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> get(
               Routes.admin_relying_party_template_path(
                 conn,
                 :template,
                 "relying_party_id",
                 "template_type"
               )
             )
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> patch(
               Routes.admin_relying_party_template_path(
                 conn,
                 :update_template,
                 "relying_party_id",
                 "template_type"
               )
             )
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }

      assert conn
             |> delete(
               Routes.admin_relying_party_template_path(
                 conn,
                 :delete_template,
                 "relying_party_id",
                 "template_type"
               )
             )
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource."
             }
    end
  end

  describe "index" do
    @tag authorized: ["relying-parties:manage:all"]
    test "lists all relying_parties", %{conn: conn} do
      conn = get(conn, Routes.admin_relying_party_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "renders not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_relying_party_path(conn, :show, SecureRandom.uuid()))
      end
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "renders a relying party", %{
      conn: conn,
      relying_party: %RelyingParty{id: id} = relying_party
    } do
      conn = get(conn, Routes.admin_relying_party_path(conn, :show, relying_party))
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end
  end

  describe "show template" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "renders not found", %{conn: conn, relying_party: %RelyingParty{id: id}} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, Routes.admin_relying_party_template_path(conn, :template, id, "unexisting"))
      end
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "renders a relying party template", %{
      conn: conn,
      relying_party: %RelyingParty{id: id}
    } do
      conn = get(conn, Routes.admin_relying_party_template_path(conn, :template, id, "new_registration"))
      assert %{"relying_party_id" => ^id, "type" => "new_registration"} = json_response(conn, 200)["data"]
    end
  end

  describe "create relying_party" do
    @tag authorized: ["relying-parties:manage:all"]
    test "renders relying_party when data is valid", %{conn: conn} do
      conn =
        post(conn, Routes.admin_relying_party_path(conn, :create), relying_party: @create_attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.admin_relying_party_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name",
               "type" => "internal"
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.admin_relying_party_path(conn, :create), relying_party: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relying_party template" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "renders relying_party when data is valid", %{
      conn: conn,
      relying_party: %RelyingParty{id: relying_party_id}
    } do
      conn =
        patch(
          conn,
          Routes.admin_relying_party_template_path(
            conn,
            :update_template,
            relying_party_id,
            "new_registration"
          ),
          template: @update_template_attrs
        )

      assert %{"id" => template_id, "content" => "some updated content"} =
               json_response(conn, 200)["data"]

      conn =
        get(
          conn,
          Routes.admin_relying_party_template_path(
            conn,
            :template,
            relying_party_id,
            "new_registration"
          )
        )

      assert %{
               "id" => ^template_id,
               "content" => "some updated content",
               "type" => "new_registration",
               "relying_party_id" => ^relying_party_id
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, relying_party: relying_party} do
      conn =
        put(conn, Routes.admin_relying_party_path(conn, :update, relying_party),
          relying_party: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relying_party template" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "respond a 404 when relying party does not exist", %{
      conn: conn
    } do
      relying_party_id = SecureRandom.uuid()
      type = "new_registration"

      assert_error_sent(404, fn ->
        delete(
          conn,
          Routes.admin_relying_party_template_path(
            conn,
            :delete_template,
            relying_party_id,
            type
          )
        )
      end)
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "respond a 404 when template does not exist", %{
      conn: conn,
      relying_party: %RelyingParty{id: relying_party_id}
    } do
      type = "new_registration"

      assert_error_sent(404, fn ->
        delete(
          conn,
          Routes.admin_relying_party_template_path(
            conn,
            :delete_template,
            relying_party_id,
            type
          )
        )
      end)
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "deletes relying_party template when template exists", %{
      conn: conn,
      relying_party: %RelyingParty{id: relying_party_id} = relying_party
    } do
      type = "new_registration"
      insert(:template, type: type, relying_party: relying_party)

      conn =
        delete(
          conn,
          Routes.admin_relying_party_template_path(
            conn,
            :delete_template,
            relying_party_id,
            type
          )
        )

      assert %{"id" => nil, "type" => "new_registration"} =
               json_response(conn, 200)["data"]
    end
  end

  describe "update relying_party" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "renders relying_party when data is valid", %{
      conn: conn,
      relying_party: %RelyingParty{id: id} = relying_party
    } do
      conn =
        put(conn, Routes.admin_relying_party_path(conn, :update, relying_party),
          relying_party: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.admin_relying_party_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "type" => "internal"
             } = json_response(conn, 200)["data"]
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, relying_party: relying_party} do
      conn =
        put(conn, Routes.admin_relying_party_path(conn, :update, relying_party),
          relying_party: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relying_party" do
    setup [:create_relying_party]

    @tag authorized: ["relying-parties:manage:all"]
    test "cannot delete admin ui relying_party", %{conn: conn} do
      client_relying_party = insert(:client_relying_party)
      current_admin_ui_client_id = System.get_env("VUE_APP_ADMIN_CLIENT_ID", "")
      System.put_env("VUE_APP_ADMIN_CLIENT_ID", client_relying_party.client_id)

      conn = delete(conn, Routes.admin_relying_party_path(conn, :delete, client_relying_party.relying_party))
      assert response(conn, 403)

      System.put_env("VUE_APP_ADMIN_CLIENT_ID", current_admin_ui_client_id)
    end

    @tag authorized: ["relying-parties:manage:all"]
    test "deletes chosen relying_party", %{conn: conn, relying_party: relying_party} do
      conn = delete(conn, Routes.admin_relying_party_path(conn, :delete, relying_party))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_relying_party_path(conn, :show, relying_party))
      end)
    end
  end

  defp create_relying_party(_) do
    relying_party = fixture(:relying_party)
    %{relying_party: relying_party}
  end
end
