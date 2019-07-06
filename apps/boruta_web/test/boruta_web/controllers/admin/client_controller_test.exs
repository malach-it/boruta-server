defmodule BorutaWeb.Admin.ClientControllerTest do
  import Boruta.Factory

  use BorutaWeb.ConnCase

  alias Boruta.Admin
  alias Boruta.Oauth.Client

  @create_attrs %{
    redirect_uri: "http://redirect.uri"
  }
  @update_attrs %{
    redirect_uri: "http://updated.redirect.uri"
  }
  @invalid_attrs %{
    sercret: "777"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all clients", %{conn: conn} do
      conn = get(conn, Routes.admin_client_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create client" do
    test "renders client when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.admin_client_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    @tag :skip
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update client" do
    setup [:create_client]

    test "renders client when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.admin_client_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    @tag :skip
    test "renders errors when data is invalid", %{conn: conn, client: client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete client" do
    setup [:create_client]

    test "deletes chosen client", %{conn: conn, client: client} do
      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.admin_client_path(conn, :show, client))
      end
    end
  end

  defp create_client(_) do
    client = insert(:client)
    {:ok, client: client}
  end
end
