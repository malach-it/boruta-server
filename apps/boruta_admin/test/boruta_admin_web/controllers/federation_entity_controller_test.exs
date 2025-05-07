defmodule BorutaAdminWeb.FederationEntityControllerTest do
  import BorutaFederation.Factory

  use BorutaAdminWeb.ConnCase

  @create_attrs %{
    organization_name: "test"
  }
  @invalid_attrs %{
    organization_name: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_federation_entity_path(conn, :index))
    assert response(conn, 401)
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      conn = get(conn, Routes.admin_federation_entity_path(conn, :index))
      assert response(conn, 403)
    end
  end

  describe "index" do
    @tag authorized: ["federation-entities:manage:all"]
    test "renders an empty list", %{conn: conn} do
      conn = get(conn, Routes.admin_federation_entity_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authorized: ["federation-entities:manage:all"]
    test "lists all federation entities", %{conn: conn} do
      insert(:entity)
      insert(:entity)
      conn = get(conn, Routes.admin_federation_entity_path(conn, :index))
      assert length(json_response(conn, 200)["data"]) == 2
    end
  end

  describe "create entity" do
    @tag authorized: ["federation-entities:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_federation_entity_path(conn, :create), federation_entity: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authorized: ["federation-entities:manage:all"]
    test "renders entity when data is valid", %{conn: conn} do
      create = post(conn, Routes.admin_federation_entity_path(conn, :create), federation_entity: @create_attrs)
      assert %{"id" => _id} = json_response(create, 201)["data"]
    end
  end

  describe "delete entity" do
    setup %{conn: conn} do
      entity = insert(:entity)

      {:ok, conn: conn, federation_entity: entity}
    end

    @tag :skip
    @tag authorized: ["federation-entities:manage:all"]
    test "returns an error when entity does not exist", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.admin_federation_entity_path(conn, :delete, SecureRandom.uuid()))
      end)
    end

    @tag :skip
    @tag authorized: ["federation-entities:manage:all"]
    test "deletes chosen entity", %{conn: conn, federation_entity: entity} do
      conn = delete(conn, Routes.admin_federation_entity_path(conn, :delete, entity))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_federation_entity_path(conn, :show, entity))
      end)
    end
  end
end
