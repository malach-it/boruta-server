defmodule BorutaGateway.Repo.Migrations.CreateServiceRegistryNodes do
  use Ecto.Migration

  def change do
    create table(:service_registry_nodes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :ip, :string, null: false
      add :name, :string, null: false

      timestamps()
    end

    create index(:service_registry_nodes, :ip, unique: true)
  end
end
