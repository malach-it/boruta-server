defmodule BorutaGateway.Repo.Migrations.AddErlangNodeNameToServiceRegistryRecords do
  use Ecto.Migration

  def change do
    alter table(:service_registry_records) do
      add(:erlang_node_name, :string)
    end
  end
end
