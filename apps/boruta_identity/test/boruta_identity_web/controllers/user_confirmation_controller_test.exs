defmodule BorutaIdentityWeb.UserConfirmationControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.Factory

  alias BorutaIdentity.Accounts
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
  end

  describe "GET /users/confirm" do
    setup %{conn: conn} do
      client_relying_party =
        insert(:client_relying_party,
          relying_party: build(:relying_party, registrable: true)
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
    test "confirms the given token once", %{conn: conn, user: user} do
      confirmation_url_fun = fn _ -> "http://test.host" end
      {:ok, token} = Accounts.deliver_user_confirmation_instructions(user, confirmation_url_fun)

      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_user(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      # When not logged in
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Account confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in(user)
        |> get(Routes.user_confirmation_path(conn, :confirm, token))

      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
      assert get_flash(conn, :error) =~ "Account confirmation link is invalid or it has expired"
      refute Accounts.get_user(user.id).confirmed_at
    end
  end
end
