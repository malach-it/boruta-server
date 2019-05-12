defmodule BorutaWeb.OauthControllerTest do
  use BorutaWeb.ConnCase, async: true

  import Boruta.Factory

  import Boruta.Factory

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "client_credentials grant" do
    setup %{conn: conn} do
      user = insert(:user)
      client = insert(:client, user_id: user.id)
      {:ok, conn: conn, client: client}
    end

    test "returns an error with invalid query parameters", %{conn: conn} do
      conn = post(conn, "/oauth/token")

      assert json_response(conn, 400) == %{
        "error" => "invalid_request",
        "error_description" => "Query params validation failed. Required property grant_type is missing at #"
      }
    end

    test "returns an error with an invalid grant type", %{conn: conn} do
      conn = post(conn, "/oauth/token?grant_type=bad_grant_type")

      assert json_response(conn, 400) == %{
        "error" => "invalid_request",
        "error_description" => "Query params validation failed. #/grant_type do match required pattern /client_credentials/"
      }
    end

    test "returns an error with invalid body parameters", %{conn: conn} do
      conn = post(conn, "/oauth/token?grant_type=client_credentials")

      assert json_response(conn, 400) == %{
        "error" => "invalid_request",
        "error_description" => "Request body validation failed. Required properties client_secret, client_id are missing at #"
      }
    end

    test "returns an error with invalid client_id", %{conn: conn} do
      conn = conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")

      conn = post(
        conn,
        "/oauth/token?grant_type=client_credentials",
        "client_id=666&client_secret=666"
      )

      assert json_response(conn, 400) == %{
        "error" => "invalid_request",
        "error_description" => "Request body validation failed. #/client_id do match required pattern /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/"
      }
    end

    test "returns an error with invalid client_id/secret couple", %{conn: conn} do
      conn = conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")

      conn = post(
        conn,
        "/oauth/token?grant_type=client_credentials",
        "client_id=6a2f41a3-c54c-fce8-32d2-0324e1c32e22&client_secret=666"
      )

      assert json_response(conn, 401) == %{
        "error" => "invalid_client",
        "error_description" => "Invalid client id or secret."
      }
    end

    test "returns an error with invalid client_secret", %{conn: conn, client: client} do
      conn = conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")

      conn = post(
        conn,
        "/oauth/token?grant_type=client_credentials",
        "client_id=#{client.id}&client_secret=666"
      )

      assert json_response(conn, 401) == %{
        "error" => "invalid_client",
        "error_description" => "Invalid client id or secret."
      }
    end

    test "returns a token response with valid client_id/client_secret", %{conn: conn, client: client} do
      conn = conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")

      conn = post(
        conn,
        "/oauth/token?grant_type=client_credentials",
        "client_id=#{client.id}&client_secret=#{client.secret}"
      )

      %{
        "access_token" => access_token,
        "token_type" => token_type,
        "expires_in" => expires_in,
        "refresh_token" => refresh_token
      } = json_response(conn, 200)
      assert access_token
      assert token_type == "bearer"
      assert expires_in
      assert refresh_token
    end
  end

  describe "implicit grant" do
    setup %{conn: conn} do
      resource_owner = insert(:user)
      user = insert(:user)
      redirect_uri = "http://redirect.uri"
      client = insert(:client, redirect_uri: redirect_uri, user_id: user.id)
      {:ok, conn: conn, client: client, redirect_uri: redirect_uri, resource_owner: resource_owner}
    end

    # TODO test differents validation cases
    test "validates request params", %{conn: conn} do
      conn = get(conn, "/oauth/authorize")

      assert response_content_type(conn, :html)
      assert response(conn, 400) =~ "Query params validation failed"
    end

    test "returns an error if client_id is invalid", %{
      conn: conn,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn = assign(conn, :current_user, resource_owner)

      conn = get(
        conn,
        Routes.oauth_path(conn, :authorize, %{
          response_type: "token",
          client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
          redirect_uri: redirect_uri,
          scope: "all",
          state: "state"
        })
      )

      assert response_content_type(conn, :html)
      assert response(conn, 401) =~ "Invalid client id or redirect_uri."
    end

    test "returns an error if scopes are invalid", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn = assign(conn, :current_user, resource_owner)

      conn = get(
        conn,
        Routes.oauth_path(conn, :authorize, %{
          response_type: "token",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: "boom",
          state: "state"
        })
      )

      assert response_content_type(conn, :html)
      assert response(conn, 400) =~ ~r/Allowed scopes for the token are .+, restricted./
    end

    test "redirect to user authentication page", %{conn: conn} do
      conn = get(
        conn,
        Routes.oauth_path(conn, :authorize, %{
          response_type: "token",
          client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
          redirect_uri: "http://redirect.uri",
          scope: "scope",
          state: "state"
        })
      )

      assert redirected_to(conn) =~ "/sessions/new"
    end

    test "stores oauth request params in session when current_user is not set", %{conn: conn} do
      conn = get(
        conn,
        Routes.oauth_path(conn, :authorize, %{
          response_type: "token",
          client_id: "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
          redirect_uri: "http://redirect.uri",
          scope: "scope",
          state: "state"
        })
      )

      assert get_session(conn, :oauth_request) == %{
        "response_type" => "token",
        "client_id" => "6a2f41a3-c54c-fce8-32d2-0324e1c32e22",
        "redirect_uri" => "http://redirect.uri",
        "scope" => "scope",
        "state" => "state"
      }
    end

    test "redirects to redirect_uri with token if user is set", %{
      conn: conn,
      client: client,
      redirect_uri: redirect_uri,
      resource_owner: resource_owner
    } do
      conn = assign(conn, :current_user, resource_owner)

      conn = get(
        conn,
        Routes.oauth_path(conn, :authorize, %{
          response_type: "token",
          client_id: client.id,
          redirect_uri: redirect_uri,
          scope: "all",
          state: "state"
        })
      )

      assert Regex.match?(
        ~r/#{redirect_uri}#access_token=.+/,
        redirected_to(conn)
      )
    end
  end
end
