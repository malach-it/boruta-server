defmodule BorutaIdentityWeb.UserRegistrationControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentity.Factory

  describe "whithout client set" do
    test "new registration redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end

    test "create registration redirects to home", %{conn: conn} do
      conn = post(conn, Routes.user_registration_path(conn, :create), %{"user" => %{}})
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "whithout client relying party" do
    setup %{conn: conn} do
      conn = init_test_session(conn, %{current_client_id: SecureRandom.uuid()})

      {:ok, conn: conn}
    end

    test "new registration redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))

      assert get_flash(conn, :error) ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."

      assert redirected_to(conn) == "/"
    end

    test "create registration redirects to home", %{conn: conn} do
      conn = post(conn, Routes.user_registration_path(conn, :create), %{"user" => %{}})

      assert get_flash(conn, :error) ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."

      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/register" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party:
            build(:relying_party,
              registrable: true
            )
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in(user_fixture()) |> get(Routes.user_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /users/register" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, registrable: true)
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    @tag :capture_log
    test "creates account and logs the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => %{"email" => email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
