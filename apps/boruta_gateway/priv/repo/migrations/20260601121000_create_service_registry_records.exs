defmodule BorutaGateway.Repo.Migrations.CreateServiceRegistryRecords do
  use Ecto.Migration

  def change do
    create table(:service_registry_records, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:node_name, :string, null: false)
      add(:ip_address, :string, null: false)
      add(:aliases, {:array, :string}, default: [], null: false)
      add(:status, :string, null: false)

      timestamps()
    end

    create(unique_index(:service_registry_records, [:ip_address, :node_name]))
  end
end
