defmodule BorutaIdentityWeb.UserConfirmationControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts
  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Repo
  import BorutaIdentity.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "whithout client set" do
    test "new confirmation redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))
      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end

    test "create confirmation redirects to home", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.user_confirmation_path(conn, :create, %{
            "user" => %{"email" => "user@email.test"}
          })
        )

      assert get_flash(conn, :error) == "Client identifier not provided."
      assert redirected_to(conn) == "/"
    end
  end

  describe "whithout client relying party" do
    setup %{conn: conn} do
      conn = init_test_session(conn, %{current_client_id: SecureRandom.uuid()})

      {:ok, conn: conn}
    end

    test "new confirmation redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))

      assert get_flash(conn, :error) ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."

      assert redirected_to(conn) == "/"
    end

    test "create confirmation redirects to home", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.user_confirmation_path(conn, :create, %{
            "user" => %{"email" => "user@email.test"}
          })
        )

      assert get_flash(conn, :error) ==
               "Relying Party not configured for given OAuth client. Please contact your administrator."

      assert redirected_to(conn) == "/"
    end
  end

  describe "whithout client confirmable configuration enabled" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, confirmable: false)
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "new confirmation redirects to home", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))

      assert get_flash(conn, :error) ==
               "Feature is not enabled for client relying party."

      assert redirected_to(conn) == "/"
    end

    test "create confirmation redirects to home", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.user_confirmation_path(conn, :create, %{
            "user" => %{"email" => "user@email.test"}
          })
        )

      assert get_flash(conn, :error) ==
               "Feature is not enabled for client relying party."

      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /users/confirm" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, confirmable: true)
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /users/confirm" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, confirmable: true)
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, user: user} do
      Repo.update!(Accounts.User.confirm_changeset(user))

      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/confirm/:token" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, confirmable: true)
        )

      conn = init_test_session(conn, %{current_client_id: client_relying_party.client_id})

      {:ok, conn: conn}
    end

    test "confirms the given token once", %{conn: conn, user: user} do
      confirmation_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Deliveries.deliver_user_confirmation_instructions(user, confirmation_url_fun)

      confirm_conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(confirm_conn) == "/"
      assert get_flash(confirm_conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_user(user.id).confirmed_at
      refute get_session(confirm_conn, :user_token)

      # When not logged in
      signed_out_conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(signed_out_conn) == Routes.user_session_path(signed_out_conn, :new)
      assert get_flash(signed_out_conn, :error) =~ "Account confirmation token is invalid or it has expired"

      # When logged in
      signed_in_conn =
        conn
        |> log_in(user)
        |> get(Routes.user_confirmation_path(conn, :confirm, token))

      assert redirected_to(signed_in_conn) == "/"
      assert get_flash(signed_in_conn, :error) =~ "Account has already been confirmed"
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Account confirmation token is invalid or it has expired"
      refute Accounts.get_user(user.id).confirmed_at
    end
  end
end
