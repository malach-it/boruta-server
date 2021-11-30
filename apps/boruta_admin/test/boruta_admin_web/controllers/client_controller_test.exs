defmodule BorutaAdminWeb.ClientControllerTest do
  import Boruta.Factory

  use BorutaAdminWeb.ConnCase

  alias Boruta.Ecto.Client

  @create_attrs %{
    redirect_uris: ["http://redirect.uri"],
    access_token_ttl: 10,
    authorization_code_ttl: 10
  }
  @update_attrs %{
    redirect_uris: ["http://updated.redirect.uri"]
  }
  @invalid_attrs %{
    redirect_uris: ["bad_uri"]
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_client_path(conn, :index))
    assert response(conn, 401)
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      conn = get(conn, Routes.admin_client_path(conn, :index))
      assert response(conn, 403)
    end
  end

  describe "index" do
    @tag authorized: ["clients:manage:all"]
    test "lists all clients", %{conn: conn} do
      conn = get(conn, Routes.admin_client_path(conn, :index))
      assert length(json_response(conn, 200)["data"]) == 1
    end
  end

  describe "create client" do
    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn} do
      create = post(conn, Routes.admin_client_path(conn, :create), client: @create_attrs)
      assert %{"id" => _id} = json_response(create, 201)["data"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update client" do
    setup %{conn: conn} do
      client = insert(:client)

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, client: client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete client" do
    setup %{conn: conn} do
      client = insert(:client)

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "deletes chosen client", %{conn: conn, client: client} do
      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.admin_client_path(conn, :show, client))
      end
    end
  end
end
