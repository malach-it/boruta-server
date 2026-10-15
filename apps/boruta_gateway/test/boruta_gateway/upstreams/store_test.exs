defmodule BorutaGateway.Upstreams.StoreTest do
  use ExUnit.Case
  use BorutaGateway.DataCase

  alias BorutaGateway.ConfigurationLoader
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

        assert Enum.any?(upstreams["global"], fn
                 {["path1"], %{id: id}} ->
                   id == a.id

                 _ ->
                   false
               end)

        assert Enum.any?(upstreams["global"], fn
                 {["path2"], %{id: id}} ->
                   id == b.id

                 _ ->
                   false
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

        assert Enum.any?(upstreams["global"], fn
                 {["path"], %{host: "updated.host"}} ->
                   true

                 _ ->
                   false
               end)
      after
        Repo.delete_all(Upstream)
      end
    end)
  end

  test "does not duplicate upstream routes when updating upstreams with multiple uris" do
    Sandbox.unboxed_run(Repo, fn ->
      try do
        {:ok, upstream} =
          Repo.insert(%Upstream{
            host: "test1.host",
            port: 1111,
            uris: ["/path", "/other-path"]
          })

        :timer.sleep(100)

        upstream = Ecto.Changeset.change(upstream, host: "updated.host")
        {:ok, upstream} = Repo.update(upstream)
        :timer.sleep(200)

        entries =
          Store.all()
          |> Map.fetch!("global")
          |> Enum.filter(fn {_path, %{id: id}} -> id == upstream.id end)

        assert Enum.count(entries) == 2
        assert Enum.all?(entries, fn {_path, %{host: host}} -> host == "updated.host" end)
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

        assert {_path, %Upstream{}} =
                 Enum.find(upstreams["global"], fn
                   {["path"], %{id: id}} -> id == a.id
                   _ -> false
                 end)

        Repo.delete(a)
        :timer.sleep(100)

        upstreams = Store.all()

        assert Enum.all?(upstreams["global"] || [], fn
                 {["path"], %{id: id}} -> id != a.id
                 _ -> false
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
          {:ok, a} =
            Repo.insert(%Upstream{host: "test1.host", port: 1111, uris: ["/matching/uri"]})

          :timer.sleep(100)

          %Upstream{id: id} = Store.match(["matching", "uri"])
          assert id == a.id
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
          {:ok, a} =
            Repo.insert(%Upstream{
              node_name: ConfigurationLoader.node_name(),
              host: "test1.host",
              port: 1111,
              uris: ["/matching/uri"]
            })

          :timer.sleep(100)

          %Upstream{id: id} = Store.sidecar_match(["matching", "uri"])
          assert id == a.id
        after
          Repo.delete_all(Upstream)
        end
      end)
    end

    test "return sidecar matching upstream from static configuration" do
      Application.delete_env(ConfigurationLoader, :node_name)

      configuration_file_path =
        :code.priv_dir(:boruta_gateway)
        |> Path.join("/test/configuration_files/full_configuration.yml")

      Application.put_env(:boruta_gateway, :configuration_path, configuration_file_path)
      :timer.sleep(100)

      Sandbox.unboxed_run(Repo, fn ->
        try do
          {:ok, a} =
            Repo.insert(%Upstream{
              node_name: "full-configuration",
              host: "test1.host",
              port: 1111,
              uris: ["/matching/uri"]
            })

          :timer.sleep(100)

          %Upstream{id: id} = Store.sidecar_match(["matching", "uri"])
          assert id == a.id
        after
          Repo.delete_all(Upstream)
        end
      end)
    end
  end
end
