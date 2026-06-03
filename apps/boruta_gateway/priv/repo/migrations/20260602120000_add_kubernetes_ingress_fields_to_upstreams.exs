defmodule BorutaGateway.Repo.Migrations.AddKubernetesIngressFieldsToUpstreams do
  use Ecto.Migration

  def up do
    alter table(:upstreams) do
      add(:managed_by, :string)
      add(:managed_id, :string)
    end

    drop_if_exists(index(:upstreams, [:node_name, :host, :port, :uris], unique: true))

    execute("""
    CREATE UNIQUE INDEX upstreams_node_name_host_port_uris_index
    ON upstreams (node_name, COALESCE(virtual_host, ''), host, port, uris)
    """)

    create(
      unique_index(:upstreams, [:managed_by, :managed_id],
        where: "managed_by IS NOT NULL AND managed_id IS NOT NULL"
      )
    )
  end

  def down do
    drop_if_exists(index(:upstreams, [:managed_by, :managed_id]))

    execute("DROP INDEX IF EXISTS upstreams_node_name_host_port_uris_index")

    create(
      unique_index(:upstreams, [:node_name, :host, :port, :uris],
        name: :upstreams_node_name_host_port_uris_index
      )
    )

    alter table(:upstreams) do
      remove(:managed_by)
      remove(:managed_id)
    end
  end
end
