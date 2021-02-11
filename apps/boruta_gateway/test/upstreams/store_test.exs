defmodule BorutaGateway.Upstreams.StoreTest do
  use ExUnit.Case
  use BorutaGateway.DataCase

  alias BorutaGateway.Upstreams.Store
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  test "stores all inserted upstreams from repo" do
    Sandbox.unboxed_run(Repo, fn ->
      try do
        {:ok, a} = Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/path1"]})
        {:ok, b} = Repo.insert(%Upstream{host: "test2.host", port: 2222, uris: ["/path2"]})
        :timer.sleep(100)

        upstreams = Store.all()
        assert Enum.any?(upstreams, fn
          ({["path1"], %{id: id}}) -> id == a.id
          (_) -> false
        end)
        assert Enum.any?(upstreams, fn
          ({["path2"], %{id: id}}) -> id == b.id
          (_) -> false
        end)
      after
        Repo.delete_all(Upstream)
      end
    end)
  end

  test "stores all updated upstreams from repo" do
    Sandbox.unboxed_run(Repo, fn ->
      try do
        {:ok, a} = Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/path"]})

        a = Ecto.Changeset.change(a, host: "updated.host")
        {:ok, _a} = Repo.update(a)
        :timer.sleep(100)

        upstreams = Store.all()
        assert Enum.any?(upstreams, fn
          ({["path"], %{host: host}}) -> host == "updated.host"
          (_) -> false
        end)
      after
        Repo.delete_all(Upstream)
      end
    end)
  end

  test "do not stores all deleted upstreams from repo" do
    Sandbox.unboxed_run(Repo, fn ->
      try do
        {:ok, a} = Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/path"]})
        :timer.sleep(100)
        upstreams = Store.all()
        assert Enum.any?(upstreams, fn
          ({["path"], %{id: id}}) -> id == a.id
          (_) -> false
        end)

        Repo.delete(a)
        :timer.sleep(100)

        upstreams = Store.all()
        assert Enum.all?(upstreams, fn
          ({["path"], %{id: id}}) -> id != a.id
          (_) -> false
        end)
      after
        Repo.delete_all(Upstream)
      end
    end)
  end

  describe "match/2" do
    test "return matching upstream" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, a} = Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/matching/uri"]})
          :timer.sleep(100)

          %Upstream{id: id} = Store.match(["matching", "uri"])
          assert  id == a.id
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end
end
