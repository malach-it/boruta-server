# defmodule Boruta.Oauth.SchemasTest do
#   use Boruta.DataCase
#
#   alias Boruta.Oauth.Schemas
#
#   describe "client" do
#     alias Boruta.Oauth.Schemas.Client
#
#     @valid_attrs %{}
#     @update_attrs %{}
#     @invalid_attrs %{}
#
#     def client_fixture(attrs \\ %{}) do
#       {:ok, client} =
#         attrs
#         |> Enum.into(@valid_attrs)
#         |> Schemas.create_client()
#
#       client
#     end
#
#     test "list_clients/0 returns all clients" do
#       client = client_fixture()
#       assert Schemas.list_clients() == [client]
#     end
#
#     test "get_client!/1 returns the client with given id" do
#       client = client_fixture()
#       assert Schemas.get_client!(client.id) == client
#     end
#
#     test "create_client/1 with valid data creates a client" do
#       assert {:ok, %Client{} = client} = Schemas.create_client(@valid_attrs)
#     end
#
#     test "create_client/1 with invalid data returns error changeset" do
#       assert {:error, %Ecto.Changeset{}} = Schemas.create_client(@invalid_attrs)
#     end
#
#     test "update_client/2 with valid data updates the client" do
#       client = client_fixture()
#       assert {:ok, %Client{} = client} = Schemas.update_client(client, @update_attrs)
#     end
#
#     test "update_client/2 with invalid data returns error changeset" do
#       client = client_fixture()
#       assert {:error, %Ecto.Changeset{}} = Schemas.update_client(client, @invalid_attrs)
#       assert client == Schemas.get_client!(client.id)
#     end
#
#     test "delete_client/1 deletes the client" do
#       client = client_fixture()
#       assert {:ok, %Client{}} = Schemas.delete_client(client)
#       assert_raise Ecto.NoResultsError, fn -> Schemas.get_client!(client.id) end
#     end
#
#     test "change_client/1 returns a client changeset" do
#       client = client_fixture()
#       assert %Ecto.Changeset{} = Schemas.change_client(client)
#     end
#   end
#
#   describe "tokens" do
#     alias Boruta.Oauth.Schemas.Token
#
#     @valid_attrs %{}
#     @update_attrs %{}
#     @invalid_attrs %{}
#
#     def token_fixture(attrs \\ %{}) do
#       {:ok, token} =
#         attrs
#         |> Enum.into(@valid_attrs)
#         |> Schemas.create_token()
#
#       token
#     end
#
#     test "list_tokens/0 returns all tokens" do
#       token = token_fixture()
#       assert Schemas.list_tokens() == [token]
#     end
#
#     test "get_token!/1 returns the token with given id" do
#       token = token_fixture()
#       assert Schemas.get_token!(token.id) == token
#     end
#
#     test "create_token/1 with valid data creates a token" do
#       assert {:ok, %Token{} = token} = Schemas.create_token(@valid_attrs)
#     end
#
#     test "create_token/1 with invalid data returns error changeset" do
#       assert {:error, %Ecto.Changeset{}} = Schemas.create_token(@invalid_attrs)
#     end
#
#     test "update_token/2 with valid data updates the token" do
#       token = token_fixture()
#       assert {:ok, %Token{} = token} = Schemas.update_token(token, @update_attrs)
#     end
#
#     test "update_token/2 with invalid data returns error changeset" do
#       token = token_fixture()
#       assert {:error, %Ecto.Changeset{}} = Schemas.update_token(token, @invalid_attrs)
#       assert token == Schemas.get_token!(token.id)
#     end
#
#     test "delete_token/1 deletes the token" do
#       token = token_fixture()
#       assert {:ok, %Token{}} = Schemas.delete_token(token)
#       assert_raise Ecto.NoResultsError, fn -> Schemas.get_token!(token.id) end
#     end
#
#     test "change_token/1 returns a token changeset" do
#       token = token_fixture()
#       assert %Ecto.Changeset{} = Schemas.change_token(token)
#     end
#   end
# end
