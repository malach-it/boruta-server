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
      assert {:ok, %Upstream{error_content_type: "application/json"}} =
               Upstreams.create_upstream(@valid_attrs)
    end

    test "create_upstream/1 preserves blank error responses" do
      assert {:ok, %Upstream{forbidden_response: "", unauthorized_response: ""}} =
               Upstreams.create_upstream(
                 Map.merge(@valid_attrs, %{
                   forbidden_response: "",
                   unauthorized_response: ""
                 })
               )
    end

    test "create_upstream/1 with rate limiting data creates an upstream" do
      assert {:ok,
              %Upstream{
                rate_limit_enabled: true,
                rate_limit_count: 20,
                rate_limit_time_unit: "minute",
                rate_limit_penality: 1_000,
                rate_limit_timeout: 10_000,
                rate_limit_memory_length: 10
              }} =
               Upstreams.create_upstream(
                 Map.merge(@valid_attrs, %{
                   rate_limit_enabled: true,
                   rate_limit_count: 20,
                   rate_limit_time_unit: "minute",
                   rate_limit_penality: 1_000,
                   rate_limit_timeout: 10_000,
                   rate_limit_memory_length: 10
                 })
               )
    end

    test "create_upstream/1 with mTLS enabled creates an https upstream" do
      assert {:ok, %Upstream{mtls_enabled: true}} =
               Upstreams.create_upstream(Map.put(@valid_attrs, :mtls_enabled, true))
    end

    test "create_upstream/1 with mTLS enabled rejects http upstreams" do
      assert {:error, changeset} =
               Upstreams.create_upstream(
                 @valid_attrs
                 |> Map.put(:scheme, "http")
                 |> Map.put(:mtls_enabled, true)
               )

      assert changeset.errors[:mtls_enabled] == {"requires https scheme", []}
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
      assert {:ok,
              %Upstream{
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

    test "create_upstream/1 with unique constraint returns error changeset" do
      Upstreams.create_upstream(@valid_attrs)

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  node_name:
                    {"has already been taken",
                     [
                       constraint: :unique,
                       constraint_name: "upstreams_node_name_host_port_uris_index"
                     ]}
                ]
              }} = Upstreams.create_upstream(@valid_attrs)
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

    test "sync_managed_upstreams/2 upserts desired managed upstreams and deletes stale ones" do
      manual_upstream = upstream_fixture(%{uris: ["/manual"]})

      {:ok, stale_upstream} =
        Upstreams.create_upstream(%{
          node_name: "global",
          virtual_host: "stale.example.com",
          scheme: "http",
          host: "stale.default.svc.cluster.local",
          port: 80,
          uris: ["/stale"],
          managed_by: "kubernetes_ingress",
          managed_id: "stale"
        })

      assert {:ok, [managed_upstream]} =
               Upstreams.sync_managed_upstreams("kubernetes_ingress", [
                 %{
                   node_name: "global",
                   virtual_host: "api.example.com",
                   scheme: "http",
                   host: "api.default.svc.cluster.local",
                   port: 80,
                   uris: ["/api"],
                   managed_id: "api"
                 }
               ])

      assert managed_upstream.managed_by == "kubernetes_ingress"
      assert managed_upstream.managed_id == "api"
      assert Upstreams.get_upstream!(manual_upstream.id)
      assert_raise Ecto.NoResultsError, fn -> Upstreams.get_upstream!(stale_upstream.id) end
    end

    test "change_upstream/1 returns a upstream changeset" do
      upstream = upstream_fixture()
      assert %Ecto.Changeset{} = Upstreams.change_upstream(upstream)
    end
  end
end
