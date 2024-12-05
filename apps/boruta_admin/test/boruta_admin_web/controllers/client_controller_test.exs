defmodule BorutaAdminWeb.ClientControllerTest do
  import Boruta.Factory

  use BorutaAdminWeb.ConnCase

  alias Boruta.Ecto.Client
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider

  @create_attrs %{
    redirect_uris: ["http://redirect.uri"],
    access_token_ttl: 10,
    authorization_code_ttl: 10,
    identity_provider: nil,
    federation_entity: nil
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

  # TODO test sub restriction
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
      assert length(json_response(conn, 200)["data"]) == 2
    end
  end

  describe "create client" do
    setup %{conn: conn} do
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider)

      {:ok, conn: conn, identity_provider: identity_provider}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_client_path(conn, :create), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when identity provider is missing", %{conn: conn} do
      create_attrs = %{@create_attrs | identity_provider: %{id: SecureRandom.uuid()}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)

      assert %{"identity_provider_id" => ["does not exist"]} =
               json_response(create, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when identity provider has invalid uuid", %{conn: conn} do
      create_attrs = %{@create_attrs | identity_provider: %{id: "bad_uuid"}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)

      assert %{"identity_provider_id" => ["has invalid format"]} =
               json_response(create, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn, identity_provider: identity_provider} do
      create_attrs = %{@create_attrs | identity_provider: %{id: identity_provider.id}}

      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)
      assert %{"id" => _id} = json_response(create, 201)["data"]
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client with a federation entity", %{
      conn: conn,
      identity_provider: identity_provider
    } do
      entity = BorutaFederation.Factory.insert(:entity)

      create_attrs = %{
        @create_attrs
        | identity_provider: %{id: identity_provider.id},
          federation_entity: %{id: entity.id}
      }

      entity_id = entity.id
      create = post(conn, Routes.admin_client_path(conn, :create), client: create_attrs)
      assert %{"id" => _id, "federation_entity" => %{"id" => ^entity_id}} = json_response(create, 201)["data"]
    end
  end

  describe "update client" do
    setup %{conn: conn} do
      client = insert(:client)
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider)

      BorutaIdentity.Factory.insert(:client_identity_provider,
        client_id: client.id,
        identity_provider: identity_provider
      )

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when data is invalid", %{conn: conn, client: client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authorized: ["clients:manage:all"]
    test "renders errors when identity provider is invalid", %{conn: conn, client: client} do
      update_attrs = Map.put(@update_attrs, "identity_provider", %{"id" => SecureRandom.uuid()})

      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: update_attrs)
      assert %{"identity_provider_id" => ["does not exist"]} = json_response(conn, 422)["errors"]
    end

    @tag authorized: ["clients:manage:all"]
    test "cannot update administration ui client", %{conn: conn, client: client} do
      current_admin_ui_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "")
      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)

      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)
      assert response(conn, 403)

      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", current_admin_ui_client_id)
    end

    @tag authorized: ["clients:manage:all"]
    test "updates client identity provider when data is valid", %{
      conn: conn,
      client: %Client{id: id} = client
    } do
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider)
      update_attrs = Map.put(@update_attrs, "identity_provider", %{"id" => identity_provider.id})

      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      assert BorutaIdentity.Repo.get_by(ClientIdentityProvider,
               client_id: id,
               identity_provider_id: identity_provider.id
             )
    end

    @tag authorized: ["clients:manage:all"]
    test "renders client when data is valid", %{conn: conn, client: %Client{id: id} = client} do
      conn = put(conn, Routes.admin_client_path(conn, :update, client), client: @update_attrs)

      assert %{
               "id" => ^id,
               "redirect_uris" => ["http://updated.redirect.uri"]
             } = json_response(conn, 200)["data"]
    end

    @tag :skip
    test "updates a client with a global key pair"
  end

  describe "regenerate client key pair" do
    setup %{conn: conn} do
      client = insert(:client)
      identity_provider = BorutaIdentity.Factory.insert(:identity_provider)

      BorutaIdentity.Factory.insert(:client_identity_provider,
        client_id: client.id,
        identity_provider: identity_provider
      )

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "regenerates client key pair", %{conn: conn, client: client} do
      public_key = client.public_key

      conn = post(conn, Routes.admin_client_path(conn, :regenerate_key_pair, client))

      assert %{
               "data" => %{
                 "public_key" => new_public_key
               }
             } = json_response(conn, 200)

      assert new_public_key != public_key
    end
  end

  describe "delete client" do
    setup %{conn: conn} do
      client = insert(:client)

      {:ok, conn: conn, client: client}
    end

    @tag authorized: ["clients:manage:all"]
    test "cannot delete administration ui client", %{conn: conn, client: client} do
      current_admin_ui_client_id = System.get_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", "")
      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", client.id)

      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 403)

      System.put_env("BORUTA_ADMIN_OAUTH_CLIENT_ID", current_admin_ui_client_id)
    end

    @tag authorized: ["clients:manage:all"]
    test "returns an error when client does not exist", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.admin_client_path(conn, :delete, SecureRandom.uuid()))
      end)
    end

    @tag authorized: ["clients:manage:all"]
    test "deletes chosen client", %{conn: conn, client: client} do
      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.admin_client_path(conn, :show, client))
      end)
    end

    @tag authorized: ["clients:manage:all"]
    test "deletes client identity provider association", %{conn: conn, client: client} do
      BorutaIdentity.Factory.insert(:client_identity_provider, client_id: client.id)

      conn = delete(conn, Routes.admin_client_path(conn, :delete, client))
      assert response(conn, 204)

      refute BorutaIdentity.Repo.get_by(ClientIdentityProvider, client_id: client.id)
    end
  end
end
