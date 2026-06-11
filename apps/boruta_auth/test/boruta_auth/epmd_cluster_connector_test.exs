defmodule BorutaAuth.EpmdClusterConnectorTest do
  use ExUnit.Case

  alias BorutaAuth.EpmdClusterConnector

  setup do
    previous_hosts = System.get_env("LIBCLUSTER_HOSTS")

    on_exit(fn ->
      case previous_hosts do
        nil -> System.delete_env("LIBCLUSTER_HOSTS")
        hosts -> System.put_env("LIBCLUSTER_HOSTS", hosts)
      end
    end)
  end

  test "hosts_from_env/0 parses comma separated node names" do
    System.put_env("LIBCLUSTER_HOSTS", "boruta@boruta-1, boruta@boruta-2")

    assert EpmdClusterConnector.hosts_from_env() == [
             :"boruta@boruta-1",
             :"boruta@boruta-2"
           ]
  end

  test "start_link/1 ignores empty host lists" do
    assert EpmdClusterConnector.start_link(hosts: []) == :ignore
  end
end
