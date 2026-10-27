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

  @tag :skip
  test "after_sign_in_path/2"

  @tag :skip
  test "after_registration_path/2"

  @tag :skip
  test "after_sign_out_path/2"

  defp with_client_request(conn, client_id) do
    {:ok, request, _claims} =
      Joken.encode_and_sign(
        %{"client_id" => client_id},
        BorutaIdentityWeb.Token.application_signer()
      )

    %{conn | query_params: %{"request" => request}}
  end
end
