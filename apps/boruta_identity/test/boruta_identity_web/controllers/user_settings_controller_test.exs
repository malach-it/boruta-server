defmodule BorutaIdentityWeb.UserSettingsControllerTest do
  use BorutaIdentityWeb.ConnCase

  import BorutaIdentity.AccountsFixtures

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  setup :register_and_log_in

  describe "GET /users/settings" do
    setup :with_a_request

    test "renders settings page", %{conn: conn, request: request} do
      conn = get(conn, Routes.user_settings_path(conn, :edit, request: request))
      response = html_response(conn, 200)
      assert response =~ "<h1>Edit user</h1>"
    end

    test "redirects if user is not logged in", %{request: request} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :edit, request: request))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new, request: request)
    end
  end

  describe "PUT /users/settings" do
    setup :with_a_request

    setup %{identity_provider: identity_provider, user: user} do
      {:ok, _identity_provider} =
        identity_provider
        |> Ecto.Changeset.change(%{backend_id: user.backend.id})
        |> Repo.update()

      :ok
    end

    @tag :skip
    test "render errors when data is invalid"

    test "updates an user with metadata", %{conn: conn, request: request, user: user} do
      {:ok, _backend} = Ecto.Changeset.change(user.backend, %{metadata_fields: [%{"attribute_name" => "test"}]}) |> Repo.update()
      conn =
        put(conn, Routes.user_settings_path(conn, :update, request: request), %{
          "user" => %{
            "current_password" => valid_user_password(),
            "metadata" => %{"test" => "test value"}
          }
        })

      assert redirected_to(conn, 302) == Routes.user_settings_path(conn, :edit, request: request)

      assert %User{metadata: %{"test" => "test value"}} = Repo.reload(user)
    end

    test "updates an user without metadata (do not override)", %{
      conn: conn,
      request: request,
      user: user
    } do
      {:ok, _user} =
        Ecto.Changeset.change(user, %{metadata: %{"test" => "test value"}}) |> Repo.update()

      conn =
        put(conn, Routes.user_settings_path(conn, :update, request: request), %{
          "user" => %{
            "current_password" => valid_user_password()
          }
        })

      assert redirected_to(conn, 302) == Routes.user_settings_path(conn, :edit, request: request)

      assert %User{metadata: %{"test" => "test value"}} = Repo.reload(user)
    end
  end
end
