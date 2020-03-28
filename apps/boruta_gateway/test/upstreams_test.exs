defmodule BorutaGateway.UpstreamsTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.Upstreams
  alias Ecto.Adapters.SQL.Sandbox

  describe "upstreams" do
    alias BorutaGateway.Upstreams.Upstream

    @valid_attrs %{scheme: "https", host: "test.host", port: 777, uris: ["/valid"]}
    @update_attrs %{host: "update.host"}
    @invalid_attrs %{port: nil}

    def upstream_fixture(attrs \\ %{}) do
      {:ok, upstream} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Upstreams.create_upstream()

      upstream
    end

    test "list_upstreams/0 returns all upstreams" do
      upstream = upstream_fixture()
      assert Upstreams.list_upstreams() == [upstream]
    end

    test "get_upstream!/1 returns the upstream with given id" do
      upstream = upstream_fixture()
      assert Upstreams.get_upstream!(upstream.id) == upstream
    end

    test "match/1 returns the upstream matching given path" do
      Sandbox.unboxed_run(Repo, fn ->
        try do
          upstream = upstream_fixture()
          :timer.sleep(100)

          %Upstream{id: id} = Upstreams.match(["valid"])
          assert id == upstream.id
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "create_upstream/1 with valid data creates a upstream" do
      assert {:ok, %Upstream{} = upstream} = Upstreams.create_upstream(@valid_attrs)
    end

    test "create_upstream/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Upstreams.create_upstream(@invalid_attrs)
    end

    test "update_upstream/2 with valid data updates the upstream" do
      upstream = upstream_fixture()
      assert {:ok, %Upstream{} = upstream} = Upstreams.update_upstream(upstream, @update_attrs)
    end

    test "update_upstream/2 with invalid data returns error changeset" do
      upstream = upstream_fixture()
      assert {:error, %Ecto.Changeset{}} = Upstreams.update_upstream(upstream, @invalid_attrs)
      assert upstream == Upstreams.get_upstream!(upstream.id)
    end

    test "delete_upstream/1 deletes the upstream" do
      upstream = upstream_fixture()
      assert {:ok, %Upstream{}} = Upstreams.delete_upstream(upstream)
      assert_raise Ecto.NoResultsError, fn -> Upstreams.get_upstream!(upstream.id) end
    end

    test "change_upstream/1 returns a upstream changeset" do
      upstream = upstream_fixture()
      assert %Ecto.Changeset{} = Upstreams.change_upstream(upstream)
    end
  end
end
