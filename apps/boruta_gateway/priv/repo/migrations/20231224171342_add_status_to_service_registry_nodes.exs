defmodule BorutaGateway.Repo.Migrations.AddStatusToServiceRegistryNodes do
  use Ecto.Migration

  def change do
    alter table(:service_registry_nodes) do
      add :status, :string, null: false, default: "up"
    end
  end
end
