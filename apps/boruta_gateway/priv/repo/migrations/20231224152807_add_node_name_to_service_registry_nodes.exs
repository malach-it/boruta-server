defmodule BorutaGateway.Repo.Migrations.AddNodeNameToServiceRegistryNodes do
  use Ecto.Migration

  def change do
    alter table(:service_registry_nodes) do
      add :node_name, :string, null: false
    end
  end
end
