defmodule BorutaGateway.Upstreams.StoreMatchingTest do
  use ExUnit.Case

  alias BorutaGateway.Upstreams.Store
  alias BorutaGateway.Upstreams.Upstream

  describe "handle_call/3 match" do
    test "matches ordered path prefixes" do
      matching_upstream = %Upstream{id: SecureRandom.uuid(), node_name: "global"}

      state = %{
        upstreams: %{
          "global" => [
            {["foo", "bar"], matching_upstream}
          ]
        }
      }

      assert {:reply, %Upstream{id: id}, ^state} =
               Store.handle_call({:match, ["foo", "bar", "baz"]}, self(), state)

      assert id == matching_upstream.id
    end

    test "does not match path segments out of order" do
      state = %{
        upstreams: %{
          "global" => [
            {["foo", "bar"], %Upstream{id: SecureRandom.uuid(), node_name: "global"}}
          ]
        }
      }

      assert {:reply, nil, ^state} =
               Store.handle_call({:match, ["bar", "foo"]}, self(), state)
    end
  end
end
