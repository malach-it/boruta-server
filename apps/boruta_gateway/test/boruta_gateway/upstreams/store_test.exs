defmodule BorutaGateway.Upstreams.StoreTest do
  use ExUnit.Case
  use BorutaGateway.DataCase

  alias BorutaGateway.Upstreams.Client
  alias BorutaGateway.Upstreams.Store
  alias BorutaGateway.Upstreams.Upstream
  alias Ecto.Adapters.SQL.Sandbox

  @tag :skip
  test "stores all inserted upstreams from repo" do
    Sandbox.unboxed_run(Repo, fn ->
      try do
        {:ok, a} = Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/path1"]})
        {:ok, b} = Repo.insert(%Upstream{host: "test2.host", port: 2222, uris: ["/path2"]})
        Store |> Process.whereis() |> Process.exit(:normal)
        :timer.sleep(100)

        upstreams = Store.all()
        assert Enum.any?(upstreams, fn
          ({["path1"], %{id: id, http_client: http_client}}) ->
            id == a.id && Process.alive?(http_client)
          (_) -> false
        end)
        assert Enum.any?(upstreams, fn
          ({["path2"], %{id: id, http_client: http_client}}) ->
            id == b.id && Process.alive?(http_client)
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
        :timer.sleep(200)

        upstreams = Store.all()
        assert Enum.any?(upstreams, fn
          ({["path"], %{host: "updated.host", http_client: http_client} = upstream}) ->
            assert Client.upstream(http_client).host == upstream.host
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
        assert {_path, %Upstream{http_client: http_client}} = Enum.find(upstreams, fn
          ({["path"], %{id: id}}) -> id == a.id
          (_) -> false
        end)
        assert Process.alive?(http_client)

        Repo.delete(a)
        :timer.sleep(100)

        upstreams = Store.all()
        assert Enum.all?(upstreams, fn
          ({["path"], %{id: id}}) -> id != a.id
          (_) -> false
        end)

        refute Process.alive?(http_client)
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

  describe "sidecar_match/2" do
    test "return sidecar matching upstream" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, a} = Repo.insert(%Upstream{node_name: Atom.to_string(node()), host: "test1.host", port: 1111, uris: ["/matching/uri"]})
          :timer.sleep(100)

          %Upstream{id: id} = Store.sidecar_match(["matching", "uri"])
          assert  id == a.id
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end
end
