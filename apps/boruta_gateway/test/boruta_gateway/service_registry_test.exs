defmodule BorutaGateway.ServiceRegistryTest do
  use BorutaGateway.DataCase

  alias BorutaGateway.Certificate
  alias BorutaGateway.ConfigurationLoader
  alias BorutaGateway.ServiceRegistry
  alias BorutaGateway.ServiceRegistry.Record

  setup do
    previous_node_name = Application.get_env(ConfigurationLoader, :node_name)
    previous_aliases = Application.get_env(ConfigurationLoader, :aliases)

    Repo.delete_all(Record)

    on_exit(fn ->
      restore_env(:node_name, previous_node_name)
      restore_env(:aliases, previous_aliases)
    end)
  end

  test "upsert_current_record!/0 inserts the current service registry record" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local", "service.internal"])

    record = ServiceRegistry.upsert_current_record!()

    assert record.node_name == "service-node"
    assert record.erlang_node_name == Atom.to_string(node())
    assert record.ip_address == ServiceRegistry.current_ip_address()
    assert record.aliases == ["service.local", "service.internal", node_hostname()]
    assert record.certificate == Certificate.pem()

    assert %{
             "certificate" => certificate,
             "certificate_paths" => %{
               "certificate" => _certificate_path,
               "root_ca_certificate" => _root_ca_certificate_path,
               "trusted_certificates" => _trusted_certificates_path
             },
             "services" => [
               %{
                 "name" => "HTTP proxy",
                 "scheme" => "http",
                 "port" => 5555,
                 "acceptors" => 8,
                 "enabled" => false,
                 "certificate" => nil
               },
               %{
                 "name" => "HTTPS proxy",
                 "scheme" => "https",
                 "port" => 4444,
                 "acceptors" => 8,
                 "enabled" => false,
                 "certificate" => https_proxy_certificate
               },
               %{"name" => "HTTP gateway", "scheme" => "http", "port" => 7777},
               %{"name" => "HTTPS gateway", "scheme" => "https", "port" => 7443},
               %{"name" => "HTTP sidecar gateway", "scheme" => "http", "port" => 7778},
               %{"name" => "HTTPS sidecar gateway", "scheme" => "https", "port" => 7444}
             ]
           } = record.configuration

    assert certificate =~ "BEGIN CERTIFICATE"
    assert https_proxy_certificate =~ "BEGIN CERTIFICATE"
    assert record.status == "online"
  end

  test "upsert_current_record!/0 updates an existing record matching ip address and node name" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    inserted_record = ServiceRegistry.upsert_current_record!()

    Application.put_env(ConfigurationLoader, :aliases, ["updated.service.local"])

    updated_record = ServiceRegistry.upsert_current_record!()

    assert updated_record.id == inserted_record.id
    assert updated_record.node_name == "service-node"
    assert updated_record.erlang_node_name == Atom.to_string(node())
    assert updated_record.aliases == ["updated.service.local", node_hostname()]
    assert updated_record.certificate == Certificate.pem()
    assert updated_record.configuration["certificate"] == Certificate.pem()
    assert Repo.aggregate(Record, :count) == 1
  end

  test "upsert_current_record!/0 updates an existing record matching node name" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    inserted_record =
      insert_record!(
        node_name: "service-node",
        erlang_node_name: "old@node",
        ip_address: "10.0.0.99",
        aliases: ["old.service.local"],
        status: "offline"
      )

    updated_record = ServiceRegistry.upsert_current_record!()

    assert updated_record.id == inserted_record.id
    assert updated_record.node_name == "service-node"
    assert updated_record.ip_address == ServiceRegistry.current_ip_address()
    assert updated_record.erlang_node_name == Atom.to_string(node())
    assert updated_record.aliases == ["service.local", node_hostname()]
    assert updated_record.status == "online"
    assert Repo.aggregate(Record, :count) == 1
  end

  test "list_records/0 returns deduplicated records from the service registry cache" do
    record = %Record{
      id: SecureRandom.uuid(),
      node_name: "cached-node",
      ip_address: "10.0.0.10",
      aliases: ["cached.local"],
      status: "online"
    }

    state = %{records: %{"10.0.0.10" => record, "cached.local" => record}}

    assert {:reply, [^record], ^state} =
             ServiceRegistry.handle_call(:list_records, self(), state)
  end

  test "all/0 returns records keyed by ip address and aliases from the service registry cache" do
    record = %Record{
      id: SecureRandom.uuid(),
      node_name: "cached-node",
      ip_address: "10.0.0.10",
      aliases: ["cached.local", "cached.internal"],
      status: "online"
    }

    records = %{
      "10.0.0.10" => record,
      "cached.local" => record,
      "cached.internal" => record
    }

    state = %{records: records}

    assert {:reply, ^records, ^state} = ServiceRegistry.handle_call(:all, self(), state)
  end

  test "service registry cache stores records from notifications" do
    root_ca = Certificate.generate_root_ca_pem!()
    root_record = root_record(root_ca)
    id = SecureRandom.uuid()
    inserted_at = ~N[2026-06-01 12:00:00]
    updated_at = ~N[2026-06-01 12:00:01]

    payload =
      Jason.encode!(%{
        "operation" => "INSERT",
        "record" => %{
          "id" => id,
          "node_name" => "cached-node",
          "ip_address" => "10.0.0.10",
          "aliases" => ["cached.local"],
          "certificate" => Certificate.pem(),
          "status" => "online",
          "inserted_at" => NaiveDateTime.to_iso8601(inserted_at),
          "updated_at" => NaiveDateTime.to_iso8601(updated_at)
        }
      })

    assert {:noreply, %{records: records}} =
             ServiceRegistry.handle_info(
               {:notification, self(), make_ref(), "service_registry_records_changed", payload},
               %{records: %{"__cluster_ca__" => root_record}}
             )

    assert %Record{id: ^id} = record = records["10.0.0.10"]
    assert records["cached.local"] == record
    assert record.node_name == "cached-node"
    assert record.ip_address == "10.0.0.10"
    assert record.aliases == ["cached.local"]
    assert record.certificate == Certificate.pem()
    assert record.status == "online"
    assert record.inserted_at == inserted_at
    assert record.updated_at == updated_at
    assert Certificate.cacerts() == [decoded_certificate(root_ca.certificate)]
  end

  test "service registry cache updates aliases from notifications" do
    root_ca = Certificate.generate_root_ca_pem!()
    root_record = root_record(root_ca)
    id = SecureRandom.uuid()

    old_record = %Record{
      id: id,
      node_name: "cached-node",
      ip_address: "10.0.0.10",
      aliases: ["old.local"],
      status: "online"
    }

    payload =
      Jason.encode!(%{
        "operation" => "UPDATE",
        "record" => %{
          "id" => id,
          "node_name" => "cached-node",
          "ip_address" => "10.0.0.10",
          "aliases" => ["new.local"],
          "certificate" => Certificate.pem(),
          "status" => "online"
        }
      })

    assert {:noreply, %{records: records}} =
             ServiceRegistry.handle_info(
               {:notification, self(), make_ref(), "service_registry_records_changed", payload},
               %{
                 records: %{
                   "__cluster_ca__" => root_record,
                   "10.0.0.10" => old_record,
                   "old.local" => old_record
                 }
               }
             )

    assert %Record{id: ^id, aliases: ["new.local"]} = records["10.0.0.10"]
    assert %Record{id: ^id, aliases: ["new.local"]} = records["new.local"]
    refute Map.has_key?(records, "old.local")
    assert Certificate.cacerts() == [decoded_certificate(root_ca.certificate)]
  end

  test "ensure_root_record!/0 creates one cluster CA root record" do
    root_record = ServiceRegistry.ensure_root_record!()
    updated_root_record = ServiceRegistry.ensure_root_record!()

    assert root_record.id == updated_root_record.id
    assert root_record.node_name == "__cluster_ca__"
    assert root_record.ip_address == "__cluster_ca__"
    assert root_record.status == "root"
    assert root_record.certificate =~ "BEGIN CERTIFICATE"
    assert root_record.private_key =~ "BEGIN PRIVATE KEY"
  end

  test "certificate generation writes the registry root CA as the local cluster CA" do
    root_ca = Certificate.generate_root_ca_pem!()
    paths = Certificate.paths()

    File.write!(paths.root_ca_certificate, "stale certificate")
    File.write!(paths.root_ca_private_key, "stale private key")

    Certificate.ensure!(root_ca)

    assert File.read!(paths.root_ca_certificate) == root_ca.certificate
    assert File.read!(paths.root_ca_private_key) == root_ca.private_key
  end

  test "gateway cacerts include system CAs while proxy cacerts stay root-only" do
    previous_certificate_config = Application.get_env(:boruta_gateway, Certificate)
    system_ca = :crypto.strong_rand_bytes(16)

    :boruta_gateway
    |> Application.get_env(Certificate, [])
    |> Keyword.put(:system_cacerts, [system_ca])
    |> then(&Application.put_env(:boruta_gateway, Certificate, &1))

    on_exit(fn ->
      case previous_certificate_config do
        nil -> Application.delete_env(:boruta_gateway, Certificate)
        config -> Application.put_env(:boruta_gateway, Certificate, config)
      end
    end)

    root_ca = Certificate.generate_root_ca_pem!()
    root_certificate = decoded_certificate(root_ca.certificate)

    Certificate.load_trusted_certificates!([root_ca.certificate])

    assert Certificate.cacerts() == [root_certificate]
    assert Certificate.gateway_cacerts() == [system_ca, root_certificate]
  end

  test "service registry process marks the current record offline on shutdown" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    {:ok, pid} = ServiceRegistry.start_link(name: nil)

    assert Repo.aggregate(Record, :count) == 2

    GenServer.stop(pid)

    assert %Record{status: "offline"} =
             Repo.get_by!(Record,
               node_name: "service-node",
               ip_address: ServiceRegistry.current_ip_address()
             )
  end

  test "service registry process touches the current record" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    {:ok, pid} = ServiceRegistry.start_link(name: nil)

    record =
      Repo.get_by!(Record,
        node_name: "service-node",
        ip_address: ServiceRegistry.current_ip_address()
      )

    stale_updated_at = ~N[2026-01-01 00:00:00]

    record
    |> Ecto.Changeset.change(updated_at: stale_updated_at)
    |> Repo.update!()

    send(pid, :touch_service_registry_record)
    :sys.get_state(pid)

    assert %{updated_at: updated_at} = Repo.get!(Record, record.id)
    assert NaiveDateTime.compare(updated_at, stale_updated_at) == :gt

    GenServer.stop(pid)
  end

  test "service registry process RPC touches reachable record nodes" do
    Application.put_env(ConfigurationLoader, :node_name, "reachable-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    reachable_record =
      insert_record!(
        node_name: "reachable-node",
        erlang_node_name: Atom.to_string(node()),
        ip_address: ServiceRegistry.current_ip_address(),
        aliases: ["reachable.local"],
        status: "online"
      )

    stale_updated_at = ~N[2026-01-01 00:00:00]

    reachable_record
    |> Ecto.Changeset.change(updated_at: stale_updated_at)
    |> Repo.update!()

    state = %{
      ip_address: ServiceRegistry.current_ip_address(),
      node_name: "service-node",
      records: %{
        ServiceRegistry.current_ip_address() => reachable_record,
        "reachable.local" => reachable_record
      },
      unresponsive_since: %{
        {reachable_record.ip_address, reachable_record.node_name} =>
          System.monotonic_time(:millisecond)
      }
    }

    assert {:noreply, %{unresponsive_since: unresponsive_since}} =
             ServiceRegistry.handle_info(:touch_service_registry_record, state)

    assert unresponsive_since == %{}
    assert %{updated_at: updated_at} = Repo.get!(Record, reachable_record.id)
    assert NaiveDateTime.compare(updated_at, stale_updated_at) == :gt
  end

  @tag capture_log: true
  test "service registry process remembers unresponsive record nodes" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")

    unresponsive_record =
      insert_record!(
        node_name: "unresponsive-node",
        erlang_node_name: "boruta@unresponsive-node",
        ip_address: "10.0.0.21",
        aliases: [],
        status: "online"
      )

    state = %{
      ip_address: ServiceRegistry.current_ip_address(),
      node_name: "service-node",
      records: %{"10.0.0.21" => unresponsive_record},
      unresponsive_since: %{}
    }

    assert {:noreply, %{records: records, unresponsive_since: unresponsive_since}} =
             ServiceRegistry.handle_info(:touch_service_registry_record, state)

    assert records["10.0.0.21"] == unresponsive_record
    assert Map.has_key?(unresponsive_since, {"10.0.0.21", "unresponsive-node"})
    assert Repo.get!(Record, unresponsive_record.id)
  end

  test "service registry process skips RPC touch for records without Erlang node names" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")

    static_record =
      insert_record!(
        node_name: "static-node",
        erlang_node_name: nil,
        ip_address: "10.0.0.10",
        aliases: ["static.local"],
        status: "online"
      )

    state = %{
      ip_address: ServiceRegistry.current_ip_address(),
      node_name: "service-node",
      records: %{
        "10.0.0.10" => static_record,
        "static.local" => static_record
      },
      unresponsive_since: %{}
    }

    assert {:noreply, %{records: records, unresponsive_since: unresponsive_since}} =
             ServiceRegistry.handle_info(:touch_service_registry_record, state)

    assert records["10.0.0.10"] == static_record
    assert records["static.local"] == static_record
    assert unresponsive_since == %{}
    assert Repo.get!(Record, static_record.id)
  end

  @tag capture_log: true
  test "service registry process remembers record nodes when RPC touch updates no record" do
    Application.put_env(ConfigurationLoader, :node_name, "missing-node")

    unresponsive_record =
      insert_record!(
        node_name: "stale-node",
        erlang_node_name: Atom.to_string(node()),
        ip_address: "10.0.0.23",
        aliases: [],
        status: "online"
      )

    state = %{
      ip_address: ServiceRegistry.current_ip_address(),
      node_name: "service-node",
      records: %{"10.0.0.23" => unresponsive_record},
      unresponsive_since: %{}
    }

    assert {:noreply, %{records: records, unresponsive_since: unresponsive_since}} =
             ServiceRegistry.handle_info(:touch_service_registry_record, state)

    assert records["10.0.0.23"] == unresponsive_record
    assert Map.has_key?(unresponsive_since, {"10.0.0.23", "stale-node"})
    assert Repo.get!(Record, unresponsive_record.id)
  end

  @tag capture_log: true
  test "service registry process deletes record nodes unresponsive for more than 30 seconds" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")

    unresponsive_record =
      insert_record!(
        node_name: "stale-unresponsive-node",
        erlang_node_name: "boruta@stale-unresponsive-node",
        ip_address: "10.0.0.22",
        aliases: ["stale-unresponsive.local"],
        status: "online"
      )

    state = %{
      ip_address: ServiceRegistry.current_ip_address(),
      node_name: "service-node",
      records: %{
        "10.0.0.22" => unresponsive_record,
        "stale-unresponsive.local" => unresponsive_record
      },
      unresponsive_since: %{
        {"10.0.0.22", "stale-unresponsive-node"} => System.monotonic_time(:millisecond) - 31_000
      }
    }

    assert {:noreply, %{records: records, unresponsive_since: unresponsive_since}} =
             ServiceRegistry.handle_info(:touch_service_registry_record, state)

    assert records == %{}
    assert unresponsive_since == %{}
    refute Repo.get(Record, unresponsive_record.id)
  end

  test "upsert_current_record!/0 marks an offline record online" do
    Application.put_env(ConfigurationLoader, :node_name, "service-node")
    Application.put_env(ConfigurationLoader, :aliases, ["service.local"])

    record = ServiceRegistry.upsert_current_record!()

    ServiceRegistry.mark_record_offline!(record.ip_address, record.node_name)

    assert %Record{status: "offline"} = Repo.get!(Record, record.id)

    updated_record = ServiceRegistry.upsert_current_record!()

    assert updated_record.id == record.id
    assert updated_record.status == "online"
  end

  defp restore_env(key, nil), do: Application.delete_env(ConfigurationLoader, key)
  defp restore_env(key, value), do: Application.put_env(ConfigurationLoader, key, value)

  defp node_hostname do
    node()
    |> Atom.to_string()
    |> String.split("@", parts: 2)
    |> case do
      [_name, host] -> host
      [_name] -> :inet.gethostname() |> elem(1) |> to_string()
    end
  end

  defp decoded_certificate(certificate) do
    certificate
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {:Certificate, der, _encoding} -> der
      _entry -> nil
    end)
  end

  defp root_record(%{certificate: certificate, private_key: private_key}) do
    %Record{
      id: SecureRandom.uuid(),
      node_name: "__cluster_ca__",
      ip_address: "__cluster_ca__",
      aliases: [],
      certificate: certificate,
      private_key: private_key,
      status: "root"
    }
  end

  defp insert_record!(attrs) do
    %Record{}
    |> Record.changeset(Map.new(attrs))
    |> Repo.insert!()
  end
end
