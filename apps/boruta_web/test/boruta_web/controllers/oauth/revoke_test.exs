defmodule BorutaWeb.Oauth.RevokeTest do
  use BorutaWeb.ConnCase

  import ExUnit.CaptureLog
  import Boruta.Factory
  import BorutaIdentity.AccountsFixtures

  alias Boruta.Ecto.Token

  setup %{conn: conn} do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn -> Logger.configure(level: previous_level) end)

    {:ok, conn: conn}
  end

  describe "revoke" do
    setup %{conn: conn} do
      client = insert(:client)

      client_token =
        insert(:token, type: "access_token", value: SecureRandom.uuid(), client: client)

      resource_owner = user_fixture()

      resource_owner_token =
        insert(:token, type: "access_token", value: "888", client: client, sub: resource_owner.id)

      {:ok,
       conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded"),
       client: client,
       client_token: client_token,
       resource_owner_token: resource_owner_token,
       resource_owner: resource_owner}
    end

    test "returns an error if request is invalid", %{conn: conn} do
      conn =
        post(
          conn,
          "/oauth/revoke"
        )

      assert json_response(conn, 400) == %{
               "error" => "invalid_request",
               "error_description" =>
                 "Request validation failed. Required properties client_id, token are missing at #."
             }
    end

    test "returns an error if client is invalid", %{conn: conn, client: client} do
      conn =
        post(
          conn,
          "/oauth/revoke",
          "client_id=#{client.id}&client_secret=bad_secret&token=token"
        )

      assert json_response(conn, 401) == %{
               "error" => "invalid_client",
               "error_description" => "Invalid client_id or client_secret."
             }
    end

    test "returns a success if token is invalid", %{conn: conn, client: client} do
      conn =
        post(
          conn,
          "/oauth/revoke",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=bad_token"
        )

      assert response(conn, 200)
    end

    test "return a success if client, token are valid", %{
      conn: conn,
      client: client,
      client_token: token
    } do
      conn =
        post(
          conn,
          "/oauth/revoke",
          "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
        )

      assert response(conn, 200)
    end

    test "revoke token if client, token are valid", %{
      conn: conn,
      client: client,
      client_token: token
    } do
      post(
        conn,
        "/oauth/revoke",
        "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
      )

      assert BorutaAuth.Repo.get_by(Token, value: token.value).revoked_at
    end

    test "logs a successful revocation with the user id and without the token", %{
      conn: conn,
      client: client,
      resource_owner: resource_owner,
      resource_owner_token: token
    } do
      log =
        capture_log([level: :info], fn ->
          conn =
            post(
              conn,
              "/oauth/revoke",
              "client_id=#{client.id}&client_secret=#{client.secret}&token=#{token.value}"
            )

          assert response(conn, 200)
        end)

      assert log =~ "authorization revoke - success"
      assert log =~ "sub=#{resource_owner.id}"
      refute log =~ token.value
    end

    test "logs a failed revocation without the submitted token", %{
      conn: conn,
      client: client
    } do
      submitted_token = "submitted-sensitive-token"

      log =
        capture_log([level: :info], fn ->
          conn =
            post(
              conn,
              "/oauth/revoke",
              "client_id=#{client.id}&client_secret=bad_secret&token=#{submitted_token}"
            )

          assert json_response(conn, 401) == %{
                   "error" => "invalid_client",
                   "error_description" => "Invalid client_id or client_secret."
                 }
        end)

      assert log =~ "authorization revoke - failure"
      assert log =~ "status=unauthorized"
      assert log =~ "error=invalid_client"
      assert log =~ ~s(error_description="Invalid client_id or client_secret.")
      refute log =~ submitted_token
    end
  end
end
