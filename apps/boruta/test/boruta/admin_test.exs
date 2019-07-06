defmodule Boruta.AdminTest do
  use Boruta.DataCase

  alias Boruta.Admin

  describe "clients" do
    alias Boruta.Oauth.Client

    @valid_attrs %{
      redirect_uri: "http://redirect.uri"
    }
    @update_attrs %{
      redirect_uri: "http://updated.redirect.uri"
    }
    @invalid_attrs %{}

    def client_fixture(attrs \\ %{}) do
      {:ok, client} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Admin.create_client()

      client
    end

    test "list_clients/0 returns all clients" do
      client = client_fixture()
      assert Admin.list_clients() == [client]
    end

    test "get_client!/1 returns the client with given id" do
      client = client_fixture()
      assert Admin.get_client!(client.id) == client
    end

    test "create_client/1 with valid data creates a client" do
      assert {:ok, %Client{} = client} = Admin.create_client(@valid_attrs)
    end

    @tag :skip
    test "create_client/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Admin.create_client(@invalid_attrs)
    end

    test "update_client/2 with valid data updates the client" do
      client = client_fixture()
      assert {:ok, %Client{} = client} = Admin.update_client(client, @update_attrs)
    end

    @tag :skip
    test "update_client/2 with invalid data returns error changeset" do
      client = client_fixture()
      assert {:error, %Ecto.Changeset{}} = Admin.update_client(client, @invalid_attrs)
      assert client == Admin.get_client!(client.id)
    end

    test "delete_client/1 deletes the client" do
      client = client_fixture()
      assert {:ok, %Client{}} = Admin.delete_client(client)
      assert_raise Ecto.NoResultsError, fn -> Admin.get_client!(client.id) end
    end

    test "change_client/1 returns a client changeset" do
      client = client_fixture()
      assert %Ecto.Changeset{} = Admin.change_client(client)
    end
  end
end
