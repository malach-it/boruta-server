defmodule BorutaGateway.Repo.Migrations.AddAliasesToServiceRegistryRecords do
  use Ecto.Migration

  def change do
    alter table(:service_registry_records) do
      add_if_not_exists(:aliases, {:array, :string}, default: [], null: false)
    end

    drop_if_exists(unique_index(:service_registry_records, [:ip_address]))
    drop_if_exists(unique_index(:service_registry_records, [:ip_address, :aliases]))
    create_if_not_exists(unique_index(:service_registry_records, [:ip_address, :node_name]))
  end
end
