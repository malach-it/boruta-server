defmodule Boruta.AdminTest do
  use Boruta.DataCase

  alias Boruta.Admin

  alias Boruta.Oauth.Client

  @valid_attrs %{
    redirect_uri: "https://redirect.uri"
  }
  @update_attrs %{
    redirect_uri: "https://updated.redirect.uri"
  }

  def client_fixture(attrs \\ %{}) do
    {:ok, client} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Admin.create_client()

    client
  end

  describe "list_clients/0" do
    test "returns all clients" do
      client = client_fixture()
      assert Admin.list_clients() == [client]
    end
  end

  describe "get_client/1" do
    test "returns the client with given id" do
      client = client_fixture()
      assert Admin.get_client!(client.id) == client
    end
  end

  describe "create_client/1" do
    @tag :skip
    test "returns error changeset with invalid redirect_uri (bad URI format)" do
      assert {:error, %Ecto.Changeset{}} = Admin.create_client(%{
        redirect_uri: "\\bad_redirect_uri"
      })
    end

    test "creates a client" do
      assert {:ok, %Client{} = client} = Admin.create_client(@valid_attrs)
    end

    test "creates a client with a secret" do
      {:ok, %Client{secret: secret}} = Admin.create_client(@valid_attrs)
      assert secret
    end
  end

  describe "update_client/2" do
    @tag :skip
    test "returns error changeset with invalid redirect_uri (bad URI format)" do
      client = client_fixture()
      assert {:error, %Ecto.Changeset{}} = Admin.update_client(client, %{
        redirect_uri: "$bad_redirect_uri"
      })
      assert client == Admin.get_client!(client.id)
    end

    test "updates the client" do
      client = client_fixture()
      assert {:ok, %Client{} = client} = Admin.update_client(client, @update_attrs)
    end
  end

  describe "delete_client/1" do
    test "deletes the client" do
      client = client_fixture()
      assert {:ok, %Client{}} = Admin.delete_client(client)
      assert_raise Ecto.NoResultsError, fn -> Admin.get_client!(client.id) end
    end
  end
end
