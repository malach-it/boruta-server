defmodule BorutaGateway.Repo.Migrations.AddVirtualHostToUpstreams do
  use Ecto.Migration

  @index_name "upstreams_node_name_host_port_uris_index"

  def up do
    alter table(:upstreams) do
      add_if_not_exists(:virtual_host, :string)
    end

    drop_if_exists(index(:upstreams, [:node_name, :host, :port, :uris], name: @index_name))

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS #{@index_name}
    ON upstreams (node_name, COALESCE(virtual_host, ''), host, port, uris)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS #{@index_name}")

    create(unique_index(:upstreams, [:node_name, :host, :port, :uris], name: @index_name))

    alter table(:upstreams) do
      remove_if_exists(:virtual_host, :string)
    end
  end
end
