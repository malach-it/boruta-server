defmodule BorutaGateway.UpstreamsTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.Upstreams
  alias Ecto.Adapters.SQL.Sandbox

  describe "upstreams" do
    alias BorutaGateway.Upstreams.Upstream

    @valid_attrs %{
      scheme: "https",
      host: "test.host",
      port: 777,
      uris: ["/valid"],
      required_scopes: %{"GET" => ["scope"]}
    }
    @update_attrs %{host: "update.host"}
    @invalid_attrs %{port: nil, required_scopes: %{"BAD" => "bad_format"}}

    def upstream_fixture(attrs \\ %{}) do
      {:ok, upstream} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Upstreams.create_upstream()

      upstream
    end

    test "list_upstreams/0 returns all upstreams" do
      upstream = upstream_fixture()
      assert Upstreams.list_upstreams() == %{"global" => [upstream]}
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
      assert {:ok, %Upstream{}} = Upstreams.create_upstream(@valid_attrs)
    end

    test "create_upstream/1 generates a secret with HS* algorithms" do
      assert {:ok, %Upstream{forwarded_token_secret: forwarded_token_secret}} =
               Upstreams.create_upstream(
                 Map.put(
                   @valid_attrs,
                   :forwarded_token_signature_alg,
                   "HS256"
                 )
               )

      assert forwarded_token_secret
    end

    test "create_upstream/1 generates a secret with RS* algorithms" do
      assert {:ok, %Upstream{
        forwarded_token_private_key: forwarded_token_private_key,
        forwarded_token_public_key: forwarded_token_public_key
      }} =
               Upstreams.create_upstream(
                 Map.put(
                   @valid_attrs,
                   :forwarded_token_signature_alg,
                   "RS256"
                 )
               )

      assert forwarded_token_private_key
      assert forwarded_token_public_key
    end

    test "create_upstream/1 with invalid data returns error changeset" do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  required_scopes: {"Schema does not allow additional properties. at #/BAD", []},
                  scheme: {"can't be blank", [validation: :required]},
                  host: {"can't be blank", [validation: :required]},
                  port: {"can't be blank", [validation: :required]}
                ]
              }} = Upstreams.create_upstream(@invalid_attrs)
    end

    test "update_upstream/2 with valid data updates the upstream" do
      upstream = upstream_fixture()
      assert {:ok, %Upstream{}} = Upstreams.update_upstream(upstream, @update_attrs)
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
