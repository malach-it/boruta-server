defmodule BorutaIdentityWeb.TotpControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures
  import BorutaIdentityWeb.Authenticable,
    only: [
      get_user_session: 1
    ]

  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Repo
  alias BorutaIdentity.Totp

  setup :with_a_request

  setup %{identity_provider: identity_provider} do
    {:ok, user} =
      user_fixture(%{backend: identity_provider.backend})
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now())
      |> Repo.update()

    %{user: user}
  end

  describe "GET /users/totp_registration" do
    test "redirects to log in", %{
      conn: conn,
      request: request
    } do
      conn =
        conn
        |> get(Routes.totp_path(conn, :new, request: request))

      assert redirected_to(conn) =~ Routes.user_session_path(conn, :new)
    end

    test "raises if identity provider not totpable", %{
      conn: conn,
      request: request,
      user: user
    } do
      assert_raise IdentityProviderError, fn ->
        conn
        |> log_in(user)
        |> get(Routes.totp_path(conn, :new, request: request))
      end
    end

    test "renders totp registration template", %{
      identity_provider: identity_provider,
      conn: conn,
      request: request,
      user: user
    } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update!()

      conn = log_in(conn, user)
      conn = conn
        |> put_session(
          :totp_authenticated,
          %{conn |> fetch_session() |> get_user_session() => true}
        )
        |> get(Routes.totp_path(conn, :new, request: request))

      assert html_response(conn, 200) =~ "Add TOTP authentication from an authenticator"
    end
  end

  describe "POST /users/totp_registration" do
    test "redirects to log in", %{
      conn: conn,
      request: request
    } do
      conn =
        conn
        |> post(Routes.totp_path(conn, :register, request: request))

      assert redirected_to(conn) =~ Routes.user_session_path(conn, :new)
    end

    test "raises if identity provider not totpable", %{
      conn: conn,
      request: request,
      user: user
    } do
      assert_raise IdentityProviderError, fn ->
        conn
        |> log_in(user)
        |> post(Routes.totp_path(conn, :register, request: request), %{"totp" => %{}})
      end
    end

    test "renders registration template with error with invalid code", %{
      identity_provider: identity_provider,
      conn: conn,
      request: request,
      user: user
    } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update!()

      totp_params = %{
        "totp_code" => "bad code",
        "totp_secret" => "bad secret"
      }

      conn =
        conn
        |> log_in(user)
        |> post(Routes.totp_path(conn, :register, request: request), %{"totp" => totp_params})

      assert html_response(conn, 422) =~ "Add TOTP authentication from an authenticator"
      assert html_response(conn, 422) =~ "Given TOTP is invalid."
    end

    test "redirects to chosse session with valid code", %{
      identity_provider: identity_provider,
      conn: conn,
      request: request,
      user: user
    } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update!()

      secret = Totp.Admin.generate_secret()

      totp_params = %{
        "totp_code" => Totp.Admin.generate_totp(secret),
        "totp_secret" => secret
      }

      conn =
        conn
        |> log_in(user)
        |> post(Routes.totp_path(conn, :register, request: request), %{"totp" => totp_params})

      assert redirected_to(conn) =~ "/user_return_to"
    end
  end
end
