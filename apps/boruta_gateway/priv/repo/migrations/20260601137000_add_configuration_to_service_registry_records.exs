defmodule BorutaGateway.Repo.Migrations.AddConfigurationToServiceRegistryRecords do
  use Ecto.Migration

  def change do
    alter table(:service_registry_records) do
      add_if_not_exists(:configuration, :map, default: %{}, null: false)
    end
  end
end
