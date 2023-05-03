defmodule BorutaIdentity.FederatedAccountsTest do
  use BorutaIdentity.DataCase

  alias BorutaIdentity.Accounts.IdentityProviderError
  alias BorutaIdentity.Accounts.SessionError
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.FederatedAccounts

  defmodule DummyFederatedSessions do
    @behaviour BorutaIdentity.Accounts.FederatedSessionApplication

    @impl BorutaIdentity.Accounts.FederatedSessionApplication
    def user_authenticated(context, user, session_token) do
      {:user_authenticated, context, user, session_token}
    end

    @impl BorutaIdentity.Accounts.FederatedSessionApplication
    def authentication_failure(context, error) do
      {:authentication_failure, context, error}
    end
  end

  describe "create_federated_session/4" do
    setup do
      federated_backend = BorutaIdentity.Factory.insert(:federated_backend)

      identity_provider =
        BorutaIdentity.Factory.insert(:identity_provider, backend: federated_backend)

      client_identity_provider =
        BorutaIdentity.Factory.insert(
          :client_identity_provider,
          identity_provider: identity_provider
        )

      bypass = Bypass.open(port: 7878)
      Bypass.up(bypass)

      {:ok,
       bypass: bypass, client_id: client_identity_provider.client_id, backend: federated_backend}
    end

    test "returns an error if client id is unknown" do
      context = :context
      access_token = "access_token"

      assert_raise IdentityProviderError, fn ->
        FederatedAccounts.create_federated_session(
          context,
          "unknown",
          "unknown",
          access_token,
          DummyFederatedSessions
        )
      end
    end

    test "returns an error if federated server is unknown", %{client_id: client_id} do
      context = :context
      access_token = "access_token"

      assert {:authentication_failure, ^context,
              %SessionError{message: "Could not fetch associated federated server."}} =
               FederatedAccounts.create_federated_session(
                 context,
                 client_id,
                 "unknown",
                 access_token,
                 DummyFederatedSessions
               )
    end

    test "returns an error if code fails", %{
      client_id: client_id,
      backend: backend,
      bypass: bypass
    } do
      federated_server = List.first(backend.federated_servers)
      context = :context
      code = "code"
      error = "error"

      Bypass.stub(bypass, "POST", federated_server["token_path"], fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(%{error: error}))
      end)

      assert {:authentication_failure, ^context,
              %SessionError{message: message}} =
               FederatedAccounts.create_federated_session(
                 context,
                 client_id,
                 federated_server["name"],
                 code,
                 DummyFederatedSessions
               )
      assert message =~ ~r/#{error}/
    end

    test "returns an error if userinfo fails", %{
      client_id: client_id,
      backend: backend,
      bypass: bypass
    } do
      federated_server = List.first(backend.federated_servers)
      context = :context
      code = "code"

      Bypass.stub(bypass, "POST", federated_server["token_path"], fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{access_token: "access_token"}))
      end)

      Bypass.stub(bypass, "GET", federated_server["userinfo_path"], fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:authentication_failure, ^context,
              %SessionError{message: "Could not fetch user information."}} =
               FederatedAccounts.create_federated_session(
                 context,
                 client_id,
                 federated_server["name"],
                 code,
                 DummyFederatedSessions
               )
    end

    test "creates user session", %{client_id: client_id, backend: backend, bypass: bypass} do
      federated_server = List.first(backend.federated_servers)
      context = :context
      code = "code"
      sub = "sub"

      Bypass.stub(bypass, "POST", federated_server["token_path"], fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{access_token: "access_token"}))
      end)

      Bypass.stub(bypass, "GET", federated_server["userinfo_path"], fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{sub: sub}))
      end)

      assert {:user_authenticated, ^context, %User{uid: ^sub}, _session_token} =
               FederatedAccounts.create_federated_session(
                 context,
                 client_id,
                 federated_server["name"],
                 code,
                 DummyFederatedSessions
               )
    end
  end
end
