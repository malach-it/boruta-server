defmodule BorutaGateway.Repo.Migrations.CreateNodeConnections do
  use Ecto.Migration

  def change do
    create table(:node_connections, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :from_id, references(:service_registry_nodes, type: :uuid, on_delete: :delete_all), null: false
      add :to_id, references(:service_registry_nodes, type: :uuid, on_delete: :delete_all), null: false
      add :status, :string, null: false

      timestamps()
    end

    create index(:node_connections, [:from_id, :to_id], unique: true)
  end
end
