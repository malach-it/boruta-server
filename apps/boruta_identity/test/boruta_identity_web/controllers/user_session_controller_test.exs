defmodule BorutaIdentityWeb.UserSessionControllerTest do
  use BorutaIdentityWeb.ConnCase, async: true

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Repo

  setup :with_a_request

  setup %{identity_provider: identity_provider} do
    {:ok, user} =
      user_fixture(%{backend: identity_provider.backend})
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now())
      |> Repo.update()

    %{user: user}
  end

  describe "GET /users/log_in" do
    test "renders log in page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_session_path(conn, :new, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
    end

    test "redirects if already logged in", %{conn: conn, user: user, request: request} do
      conn = conn |> log_in(user) |> get(Routes.user_session_path(conn, :new, request: request))
      assert redirected_to(conn) == "/user_return_to"
    end
  end

  describe "POST /users/log_in" do
    test "logs the user in with remember me", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{
            "email" => user.username,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_boruta_identity_web_user_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "returns unauthorized when not confirmed", %{
      conn: conn,
      request: request,
      identity_provider: identity_provider
    } do
      user = user_fixture(%{backend: identity_provider.backend})

      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      response = html_response(conn, 401)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
      assert response =~ "Email confirmation is required to authenticate."
    end

    test "returns unauthorized with invalid credentials", %{
      conn: conn,
      user: user,
      request: request
    } do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => "invalid_password"}
        })

      response = html_response(conn, 401)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end

    test "logs the user in", %{conn: conn, user: user, request: request} do
      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/user_return_to"
    end

    test "logs the user in with totp identity provider", %{
      conn: conn,
      user: user,
      request: request,
      identity_provider: identity_provider
    } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update()

      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/user_return_to"
    end

    test "returns totp template with totp identity provider and totp registered user", %{
      conn: conn,
      user: user,
      request: request,
      identity_provider: identity_provider
    } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update()

      Ecto.Changeset.change(user, %{
        totp_registered_at: DateTime.utc_now()
      })
      |> Repo.update()

      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert html_response(conn, 200) =~ ~r/TOTP authentication/
    end

    test "returns totp template with totp enforced identity provider and totp registered user", %{
      conn: conn,
      user: user,
      request: request,
      identity_provider: identity_provider
    } do
      Ecto.Changeset.change(identity_provider, %{
        enforce_totp: true,
        totpable: true
      })
      |> Repo.update()

      Ecto.Changeset.change(user, %{
        totp_registered_at: DateTime.utc_now()
      })
      |> Repo.update()

      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert html_response(conn, 200) =~ ~r/TOTP authentication/
    end

    test "redirects to totp registration with totp enforced identity provider", %{
      conn: conn,
      user: user,
      request: request,
      identity_provider: identity_provider
    } do
      Ecto.Changeset.change(identity_provider, %{
        enforce_totp: true,
        totpable: true
      })
      |> Repo.update()

      conn =
        post(conn, Routes.user_session_path(conn, :create, request: request), %{
          "user" => %{"email" => user.username, "password" => valid_user_password()}
        })

      assert redirected_to(conn) =~ Routes.totp_path(conn, :new)
    end
  end

  describe "GET /users/totp_authenticate" do
    test "redirects to login", %{
      conn: conn,
      request: request
    } do
      conn =
        conn
        |> get(Routes.user_session_path(conn, :initialize_totp, request: request))

      assert redirected_to(conn) =~ Routes.user_session_path(conn, :new)
    end

    test "returns totp template with totp enforced identity provider and logged in user",
         %{
           conn: conn,
           user: user,
           request: request,
           identity_provider: identity_provider
         } do
      Ecto.Changeset.change(identity_provider, %{totpable: true, enforce_totp: true})
      |> Repo.update()

      conn =
        conn
        |> log_in(user)
        |> get(Routes.user_session_path(conn, :initialize_totp, request: request))

      assert redirected_to(conn) =~ Routes.totp_path(conn, :new)
    end

    test "returns totp template with totp enforced identity provider and totp logged in registered user",
         %{
           conn: conn,
           user: user,
           request: request,
           identity_provider: identity_provider
         } do
      Ecto.Changeset.change(identity_provider, %{
        totpable: true,
        enforce_totp: true
      })
      |> Repo.update()

      Ecto.Changeset.change(user, %{
        totp_registered_at: DateTime.utc_now()
      })
      |> Repo.update()

      conn =
        conn
        |> log_in(user)
        |> get(Routes.user_session_path(conn, :initialize_totp, request: request))

      assert html_response(conn, 200) =~ ~r/TOTP authentication/
    end

    test "returns totp template with totp identity provider and totp logged in registered user",
         %{
           conn: conn,
           user: user,
           request: request,
           identity_provider: identity_provider
         } do
      Ecto.Changeset.change(identity_provider, %{totpable: true}) |> Repo.update()

      Ecto.Changeset.change(user, %{
        totp_registered_at: DateTime.utc_now()
      })
      |> Repo.update()

      conn =
        conn
        |> log_in(user)
        |> get(Routes.user_session_path(conn, :initialize_totp, request: request))

      assert html_response(conn, 200) =~ ~r/TOTP authentication/
    end
  end

  describe "GET /users/log_out" do
    test "logs the user out", %{conn: conn, user: user, request: request} do
      conn =
        conn |> log_in(user) |> get(Routes.user_session_path(conn, :delete, request: request))

      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_session_path(conn, :delete, request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
