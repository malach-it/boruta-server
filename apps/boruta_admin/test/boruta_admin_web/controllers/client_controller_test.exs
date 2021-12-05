defmodule BorutaAdminWeb.ClientControllerTest do
  import Boruta.Factory

  use BorutaAdminWeb.ConnCase

  alias Boruta.Ecto.Client
  alias BorutaIdentity.RelyingParties.ClientRelyingParty

  @create_attrs %{
    redirect_uris: ["http://redirect.uri"],
    access_token_ttl: 10,
    authorization_code_ttl: 10,
    relying_party: nil
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
    setup %{conn: conn} do
      relying_party = BorutaIdentity.Factory.insert(:relying_party)

      {:ok, conn: conn, relying_party: relying_party}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when relying party is missing", %{conn: conn} do
      create_attrs = %{@create_attrs|relying_party: %{id: SecureRandom.uuid()}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)
      assert %{"relying_party_id" => ["does not exist"]} = json_response(create, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when relying party has invalid uuid", %{conn: conn} do
      create_attrs = %{@create_attrs|relying_party: %{id: "bad_uuid"}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)
      assert %{"relying_party_id" => ["has invalid format"]} = json_response(create, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn, relying_party: relying_party} do
      create_attrs = %{@create_attrs|relying_party: %{id: relying_party.id}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)
      assert %{"id" => _id} = json_response(create, 201)["data"]
    end
  end

  describe "update client" do
    setup %{conn: conn} do
      client = insert(:client)
      relying_party = BorutaIdentity.Factory.insert(:relying_party)
      BorutaIdentity.Factory.insert(:client_relying_party, client_id: client.id, relying_party: relying_party)

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, client: client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when relying party is invalid", %{conn: conn, client: client} do
      update_attrs = Map.put(@update_attrs, "relying_party", %{"id" => SecureRandom.uuid()})

      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: update_attrs)
      assert %{"relying_party_id" => ["does not exist"]} = json_response(conn, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "updates client relying party when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      relying_party = BorutaIdentity.Factory.insert(:relying_party)
      update_attrs = Map.put(@update_attrs, "relying_party", %{"id" => relying_party.id})

      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      assert BorutaIdentity.Repo.get_by(ClientRelyingParty, client_id: id, relying_party_id: relying_party.id)
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)
      assert %{
        "id" => ^id,
        "redirect_uris" => ["http://updated.redirect.uri"]
      } = json_response(conn, 200)["data"]
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

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_client_path(conn, :show, client))
      end)
    end
  end
end
