defmodule BorutaGateway.Repo.Migrations.AddUniqueIndexToServiceRegistryRecordsNodeName do
  use Ecto.Migration

  def change do
    create(unique_index(:service_registry_records, [:node_name]))
  end
end
