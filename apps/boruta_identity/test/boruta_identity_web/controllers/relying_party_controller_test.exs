defmodule BorutaIdentityWeb.RelyingPartyControllerTest do
  use BorutaIdentityWeb.ConnCase

  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  @create_attrs %{
    name: "some name",
    type: "some type"
  }
  @update_attrs %{
    name: "some updated name",
    type: "some updated type"
  }
  @invalid_attrs %{name: nil, type: nil}

  def fixture(:relying_party) do
    {:ok, relying_party} = RelyingParties.create_relying_party(@create_attrs)
    relying_party
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all relying_parties", %{conn: conn} do
      conn = get(conn, Routes.relying_party_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create relying_party" do
    test "renders relying_party when data is valid", %{conn: conn} do
      conn = post(conn, Routes.relying_party_path(conn, :create), relying_party: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.relying_party_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name",
               "type" => "some type"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.relying_party_path(conn, :create), relying_party: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relying_party" do
    setup [:create_relying_party]

    test "renders relying_party when data is valid", %{conn: conn, relying_party: %RelyingParty{id: id} = relying_party} do
      conn = put(conn, Routes.relying_party_path(conn, :update, relying_party), relying_party: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.relying_party_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "type" => "some updated type"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, relying_party: relying_party} do
      conn = put(conn, Routes.relying_party_path(conn, :update, relying_party), relying_party: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relying_party" do
    setup [:create_relying_party]

    test "deletes chosen relying_party", %{conn: conn, relying_party: relying_party} do
      conn = delete(conn, Routes.relying_party_path(conn, :delete, relying_party))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.relying_party_path(conn, :show, relying_party))
      end
    end
  end

  defp create_relying_party(_) do
    relying_party = fixture(:relying_party)
    %{relying_party: relying_party}
  end
end
