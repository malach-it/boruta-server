defmodule BorutaAdminWeb.UpstreamControllerTest do
  use BorutaAdminWeb.ConnCase, async: false

  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  @create_attrs %{
    scheme: "https",
    host: "host.test",
    port: 7777
  }
  @update_attrs %{
    host: "host.update"
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
    assert conn
           |> get(Routes.admin_upstream_path(conn, :index))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> post(Routes.admin_upstream_path(conn, :create))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> patch(Routes.admin_upstream_path(conn, :update, "id"))
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }

    assert conn
           |> delete(Routes.admin_upstream_path(conn, :delete, "id"))
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
             |> get(Routes.admin_upstream_path(conn, :index))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> post(Routes.admin_upstream_path(conn, :create))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> patch(Routes.admin_upstream_path(conn, :update, "id"))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }

      assert conn
             |> delete(Routes.admin_upstream_path(conn, :delete, "id"))
             |> json_response(403) == %{
               "code" =>"FORBIDDEN",
               "message" =>"You are forbidden to access this resource.",
               "errors" =>%{
                 "resource" =>["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["upstreams:manage:all"]
    test "lists all upstreams", %{conn: conn} do
      conn = get(conn, Routes.admin_upstream_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create upstream" do
    @tag authorized: ["upstreams:manage:all"]
    test "renders upstream when data is valid", %{conn: conn} do
      conn = post(conn, Routes.admin_upstream_path(conn, :create), upstream: @create_attrs)
      assert %{"id" => _id} = json_response(conn, 201)["data"]
    end

    @tag authorized: ["upstreams:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_upstream_path(conn, :create), upstream: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update upstream" do
    setup %{conn: conn} do
      upstream = fixture(:upstream)

      {:ok, conn: conn, upstream: upstream}
    end

    @tag authorized: ["upstreams:manage:all"]
    test "renders upstream when data is valid", %{
      conn: conn,
      upstream: %Upstream{id: id} = upstream
    } do
      conn =
        put(conn, Routes.admin_upstream_path(conn, :update, upstream), upstream: @update_attrs)

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag authorized: ["upstreams:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, upstream: upstream} do
      conn =
        put(conn, Routes.admin_upstream_path(conn, :update, upstream), upstream: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete upstream" do
    setup %{conn: conn} do
      upstream = fixture(:upstream)

      {:ok, conn: conn, upstream: upstream}
    end

    @tag authorized: ["upstreams:manage:all"]
    test "deletes chosen upstream", %{conn: conn, upstream: upstream} do
      conn = delete(conn, Routes.admin_upstream_path(conn, :delete, upstream))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_upstream_path(conn, :show, upstream))
      end)
    end
  end
end
