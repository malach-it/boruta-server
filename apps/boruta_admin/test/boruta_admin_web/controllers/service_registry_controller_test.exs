defmodule BorutaAdminWeb.ServiceRegistryControllerTest do
  use BorutaAdminWeb.ConnCase, async: false

  alias BorutaGateway.Repo
  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Record

  setup %{conn: conn} do
    Repo.delete_all(Record)

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "returns a 401", %{conn: conn} do
    assert conn
           |> get("/api/upstreams/service-registry")
           |> json_response(401) == %{
             "code" => "UNAUTHORIZED",
             "message" => "You are unauthorized to access this resource.",
             "errors" => %{
               "resource" => ["you are unauthorized to access this resource."]
             }
           }
  end

  describe "with bad scope" do
    @tag authorized: ["bad:scope"]
    test "returns a 403", %{conn: conn} do
      assert conn
             |> get("/api/upstreams/service-registry")
             |> json_response(403) == %{
               "code" => "FORBIDDEN",
               "message" => "You are forbidden to access this resource.",
               "errors" => %{
                 "resource" => ["you are forbidden to access this resource."]
               }
             }
    end
  end

  describe "index" do
    @tag authorized: ["upstreams:manage:all"]
    test "lists service registry records", %{conn: conn} do
      %Record{
        node_name: "gateway-node",
        ip_address: "10.0.0.10",
        aliases: ["gateway.local", "gateway.internal"],
        configuration: %{
          "certificate" => "node certificate",
          "certificate_paths" => %{
            "certificate" => "/node/gateway.crt",
            "root_ca_certificate" => "/node/cluster_ca.crt",
            "trusted_certificates" => "/node/service_registry_cacerts.pem"
          },
          "services" => [
            %{
              "name" => "HTTP proxy",
              "scheme" => "http",
              "port" => 15_555,
              "acceptors" => 4,
              "enabled" => true,
              "certificate" => nil
            },
            %{
              "name" => "HTTPS proxy",
              "scheme" => "https",
              "port" => 14_444,
              "acceptors" => 4,
              "enabled" => true,
              "certificate" => "node https proxy certificate"
            }
          ]
        },
        status: "online"
      }
      |> Repo.insert!()

      ServiceRegistry.hydrate()

      conn = get(conn, "/api/upstreams/service-registry")
      response = json_response(conn, 200)

      assert [
               %{
                 "id" => _id,
                 "node_name" => "gateway-node",
                 "ip_address" => "10.0.0.10",
                 "aliases" => ["gateway.local", "gateway.internal"],
                 "configuration" => configuration,
                 "status" => "online",
                 "inserted_at" => _inserted_at,
                 "updated_at" => _updated_at
               }
             ] = response["data"]

      assert %{
               "certificate" => "node certificate",
               "certificate_paths" => %{
                 "certificate" => "/node/gateway.crt",
                 "root_ca_certificate" => "/node/cluster_ca.crt",
                 "trusted_certificates" => "/node/service_registry_cacerts.pem"
               },
               "services" => services
             } = configuration

      assert [
               %{
                 "name" => "HTTP proxy",
                 "scheme" => "http",
                 "port" => 15_555,
                 "acceptors" => 4,
                 "enabled" => true,
                 "certificate" => nil
               },
               %{
                 "name" => "HTTPS proxy",
                 "scheme" => "https",
                 "port" => 14_444,
                 "acceptors" => 4,
                 "enabled" => true,
                 "certificate" => "node https proxy certificate"
               }
             ] = services
    end
  end
end
