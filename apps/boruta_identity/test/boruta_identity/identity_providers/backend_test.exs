defmodule BorutaIdentity.IdentityProviders.BackendTest do
  use BorutaIdentity.DataCase

  import BorutaIdentity.Factory

  alias BorutaIdentity.IdentityProviders.Backend

  describe "federated_login_url/2" do
    test "returns an empty string" do
      backend = insert(:backend)

      assert Backend.federated_login_url(backend, "inexistant") == ""
    end

    test "returns login url" do
      federated_servers = [
        %{
          "name" => "name",
          "client_id" => "client_id",
          "client_secret" => "client_secret",
          "base_url" => "https://host.test",
          "authorize_path" => "/authorize",
          "token_path" => "/token",
          "scope" => "openid email"
        }
      ]

      backend = insert(:backend, federated_servers: federated_servers)

      assert Backend.federated_login_url(backend, "name", "state") ==
               "https://host.test/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%3A4003%2Fbackends%2F#{backend.id}%2Fname%2Fcallback&response_type=code&scope=openid+email&state=state"
    end

    test "returns an empty string when discovery response is malformed" do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
        Plug.Conn.resp(conn, 200, "not json")
      end)

      federated_servers = [
        %{
          "name" => "name",
          "client_id" => "client_id",
          "client_secret" => "client_secret",
          "base_url" => "http://localhost:#{bypass.port}",
          "discovery_path" => "/.well-known/openid-configuration",
          "scope" => "openid email"
        }
      ]

      backend = insert(:backend, federated_servers: federated_servers)

      assert Backend.federated_login_url(backend, "name", "state") == ""
    end
  end
end
