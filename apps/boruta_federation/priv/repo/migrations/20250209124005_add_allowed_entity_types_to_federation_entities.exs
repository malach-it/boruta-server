defmodule BorutaFederation.Repo.Migrations.AddAllowedEntityTypesToFederationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :allowed_entity_types, {:array, :string}
    end
  end
end
