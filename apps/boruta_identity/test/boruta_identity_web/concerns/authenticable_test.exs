defmodule BorutaIdentityWeb.AuthenticableTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentityWeb.Authenticable

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BorutaIdentityWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user: user_fixture(), conn: conn}
  end

  describe "after_sign_in_path" do
    setup :with_a_request

    test "returns root path", %{conn: conn} do
      conn = %{conn | query_params: %{}}

      assert Authenticable.after_sign_in_path(conn) == "/"
    end

    test "returns session stored path if provided", %{conn: conn, request: request} do
      conn = %{conn | query_params: %{"request" => request}}

      assert Authenticable.after_sign_in_path(conn) == "/user_return_to"
    end
  end

  describe "redirect_uri_from_request/1" do
    test "reads the redirect URI from a signed authorization request", %{conn: conn} do
      redirect_uri = "https://client.example:8443/callback?view=full&next=%2Fprivate"
      request = redirect_request(redirect_uri)
      conn = %{conn | query_params: %{"request" => request}}

      assert Authenticable.redirect_uri_from_request(conn) == redirect_uri
    end

    test "reads the redirect URI from a stateful authorization request", %{conn: conn} do
      redirect_uri = "https://client.example/callback"

      conn =
        conn
        |> put_session(:authorization_request, %{
          "id" => "pending-request",
          "jwt" => redirect_request(redirect_uri)
        })
        |> Map.put(:query_params, %{"request" => "pending-request"})

      assert Authenticable.redirect_uri_from_request(conn) == redirect_uri
      assert Authenticable.redirect_uri_from_request(%{conn | query_params: %{}}) == redirect_uri
    end

    test "returns nil for missing, invalid or unrelated requests", %{conn: conn} do
      for params <- [%{}, %{"request" => "invalid"}, %{"request" => redirect_request(nil)}] do
        assert Authenticable.redirect_uri_from_request(%{conn | query_params: params}) == nil
      end
    end
  end

  test "sessions for separate client IDs coexist and logout removes only one", %{conn: conn} do
    first_client_id = SecureRandom.uuid()
    second_client_id = SecureRandom.uuid()
    first_token = generate_user_session_token(user_fixture())
    second_token = generate_user_session_token(user_fixture())

    conn =
      conn
      |> Map.put(:body_params, %{})
      |> with_client_request(first_client_id)
      |> Authenticable.store_user_session(first_token)
      |> with_client_request(second_client_id)
      |> Authenticable.store_user_session(second_token)

    assert conn |> with_client_request(first_client_id) |> Authenticable.get_user_session() ==
             first_token

    assert conn |> with_client_request(second_client_id) |> Authenticable.get_user_session() ==
             second_token

    conn = conn |> with_client_request(first_client_id) |> Authenticable.remove_user_session()

    refute Authenticable.get_user_session(conn)

    assert conn |> with_client_request(second_client_id) |> Authenticable.get_user_session() ==
             second_token
  end

  test "logout preserves the stateful authorization request", %{conn: conn} do
    client_id = SecureRandom.uuid()

    {:ok, jwt, _} =
      Joken.encode_and_sign(
        %{"client_id" => client_id, "user_return_to" => "/oauth/authorize?state=original"},
        BorutaIdentityWeb.Token.application_signer()
      )

    request = %{"id" => "pending-request", "jwt" => jwt}

    conn =
      conn
      |> put_session(:authorization_request, request)
      |> put_session(:user_token, %{client_id => "old-session"})
      |> Map.put(:query_params, %{"request" => "pending-request"})
      |> Phoenix.Controller.fetch_flash()
      |> BorutaIdentityWeb.UserSessionController.session_deleted()

    assert get_session(conn, :authorization_request) == request
    assert get_session(conn, :user_token) == %{}
    assert Authenticable.client_id_from_request(conn) == client_id
    assert redirected_to(conn) =~ "request=pending-request"
  end

  @tag :skip
  test "after_sign_in_path/2"

  @tag :skip
  test "after_registration_path/2"

  @tag :skip
  test "after_sign_out_path/2"

  defp redirect_request(redirect_uri) do
    query = if redirect_uri, do: URI.encode_query(%{redirect_uri: redirect_uri}), else: ""

    {:ok, request, _claims} =
      Joken.encode_and_sign(
        %{"user_return_to" => "/oauth/authorize?" <> query},
        BorutaIdentityWeb.Token.application_signer()
      )

    request
  end

  defp with_client_request(conn, client_id) do
    {:ok, request, _claims} =
      Joken.encode_and_sign(
        %{"client_id" => client_id},
        BorutaIdentityWeb.Token.application_signer()
      )

    %{conn | query_params: %{"request" => request}}
  end
end
