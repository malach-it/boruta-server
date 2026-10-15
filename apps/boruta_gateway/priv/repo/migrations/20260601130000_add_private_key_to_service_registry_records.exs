defmodule BorutaGateway.Repo.Migrations.AddPrivateKeyToServiceRegistryRecords do
  use Ecto.Migration

  def change do
    alter table(:service_registry_records) do
      add_if_not_exists(:private_key, :text)
    end
  end
end
