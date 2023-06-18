defmodule BorutaGateway.ServiceRegistryTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.ServiceRegistry

  describe "nodes" do
    alias BorutaGateway.ServiceRegistry.Node

    test "current_node/0 returns current node" do
      Application.put_env(ConfigurationLoader, :node_name, "service")

      assert ServiceRegistry.current_node() == %Node{
               name: "service",
               ip: "nohost"
             }
    end

    test "upsert_node/1 creates a node" do
      node = %Node{
        name: "updated",
        ip: "nohost"
      }

      assert {:ok, %Node{name: "updated", ip: "nohost"}} = ServiceRegistry.upsert_node(node)
    end

    test "upsert_node/1 updates a node" do
      node = %Node{
        name: "updated",
        ip: "nohost"
      }

      assert {:ok, %Node{name: "updated", ip: "nohost"}} = ServiceRegistry.upsert_node(node)
    end
  end
end
