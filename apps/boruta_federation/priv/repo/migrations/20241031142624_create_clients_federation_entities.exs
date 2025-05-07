defmodule BorutaFederation.Repo.Migrations.CreateClientsFederationEntities do
  use Ecto.Migration

  def change do
    create table(:clients_federation_entities, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:client_id, :uuid)
      add(:federation_entity_id, references(:federation_entities, type: :uuid, on_delete: :delete_all), null: false)
      timestamps()
    end

    create index(:clients_federation_entities, :client_id, unique: true)
  end
end
