defmodule BorutaWeb.Admin.ClientControllerTest do
  import Boruta.Factory

  use BorutaWeb.ConnCase

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
    setup %{conn: conn} do
      token = insert(:token, type: "access_token")
      conn = conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn}
    end

    test "returns a 403", %{conn: conn} do
      conn = get(conn, Routes.admin_scope_path(conn, :index))
      assert response(conn, 403)
    end
  end

  describe "index" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "clients:manage:all")
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn}
    end

    test "lists all clients", %{conn: conn} do
      conn = get(conn, Routes.admin_client_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create client" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "clients:manage:all")
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn}
    end

    test "renders client when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.admin_client_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update client" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "clients:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client}
    end

    test "renders client when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.admin_client_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, client: client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete client" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "clients:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client}
    end

    test "deletes chosen client", %{conn: conn, client: client} do
      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.admin_client_path(conn, :show, client))
      end
    end
  end
end
