defmodule BorutaGateway.ServiceRegistry.MonitorTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.Repo
  alias BorutaGateway.ServiceRegistry.Monitor
  alias BorutaGateway.ServiceRegistry.Node

  describe "start_link/1" do
    test "starts" do
      pid = Process.whereis(Monitor)

      assert Process.alive?(pid)
    end

    test "persists active nodes" do
      assert [%Node{name: "nonode@nohost", ip: "nohost"}] = Repo.all(Node)
    end
  end
end
