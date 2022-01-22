defmodule BorutaAdminWeb.RelyingPartyControllerTest do
  use BorutaAdminWeb.ConnCase

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
           |> response(401)

    assert conn
           |> post(Routes.admin_relying_party_path(conn, :create))
           |> response(401)

    assert conn
           |> patch(Routes.admin_relying_party_path(conn, :update, "id"))
           |> response(401)

    assert conn
           |> delete(Routes.admin_relying_party_path(conn, :delete, "id"))
           |> response(401)

    assert conn
           |> get(
             Routes.admin_relying_party_template_path(
               conn,
               :template,
               "relying_party_id",
               "template_type"
             )
           )
           |> response(401)

    assert conn
           |> patch(
             Routes.admin_relying_party_template_path(
               conn,
               :update_template,
               "relying_party_id",
               "template_type"
             )
           )
           |> response(401)
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get(Routes.admin_relying_party_path(conn, :index))
             |> response(403)

      assert conn
             |> post(Routes.admin_relying_party_path(conn, :create))
             |> response(403)

      assert conn
             |> patch(Routes.admin_relying_party_path(conn, :update, "id"))
             |> response(403)

      assert conn
             |> delete(Routes.admin_relying_party_path(conn, :delete, "id"))
             |> response(403)

      assert conn
             |> get(
               Routes.admin_relying_party_template_path(
                 conn,
                 :template,
                 "relying_party_id",
                 "template_type"
               )
             )
             |> response(403)

      assert conn
             |> patch(
               Routes.admin_relying_party_template_path(
                 conn,
                 :update_template,
                 "relying_party_id",
                 "template_type"
               )
             )
             |> response(403)
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
