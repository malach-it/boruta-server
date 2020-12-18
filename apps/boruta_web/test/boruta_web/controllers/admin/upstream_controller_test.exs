defmodule BorutaWeb.Admin.UpstreamControllerTest do
  use BorutaWeb.ConnCase, async: false

  import Boruta.Factory

  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  @create_attrs %{
    scheme: "https",
    host: "host.test",
    port: 7777
  }
  @update_attrs %{
    host: "host.update",
  }
  @invalid_attrs %{
    host: nil
  }

  def fixture(:upstream) do
    {:ok, upstream} = Upstreams.create_upstream(@create_attrs)
    upstream
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    conn = get(conn, Routes.admin_client_path(conn, :index))
    assert response(conn, 401)
  end

  describe "index" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "upstreams:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client}
    end

    test "lists all upstreams", %{conn: conn} do
      conn = get(conn, Routes.admin_upstream_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create upstream" do
    setup %{conn: conn} do
      token = insert(:token, type: "access_token", scope: "upstreams:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client}
    end

    test "renders upstream when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_upstream_path(conn, :create), upstream: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.admin_upstream_path(conn, :show, id))

      assert %{
        "id" => id
      } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_upstream_path(conn, :create), upstream: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update upstream" do
    setup %{conn: conn} do
      upstream = fixture(:upstream)
      token = insert(:token, type: "access_token", scope: "upstreams:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client, upstream: upstream}
    end

    test "renders upstream when data is valid", %{conn: conn, upstream: %Upstream{id: id} = upstream} do
      conn = put(conn, Routes.admin_upstream_path(conn, :update, upstream), upstream: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.admin_upstream_path(conn, :show, id))

      assert %{
        "id" => id
      } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, upstream: upstream} do
      conn = put(conn, Routes.admin_upstream_path(conn, :update, upstream), upstream: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete upstream" do
    setup %{conn: conn} do
      upstream = fixture(:upstream)
      token = insert(:token, type: "access_token", scope: "upstreams:manage:all")
      client = insert(:client)
      conn = conn
        |> put_req_header("authorization", "Bearer #{token.value}")
      {:ok, conn: conn, client: client, upstream: upstream}
    end

    test "deletes chosen upstream", %{conn: conn, upstream: upstream} do
      conn = delete(conn, Routes.admin_upstream_path(conn, :delete, upstream))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.admin_upstream_path(conn, :show, upstream))
      end
    end
  end
end
