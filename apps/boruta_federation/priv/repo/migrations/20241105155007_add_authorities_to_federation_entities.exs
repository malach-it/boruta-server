defmodule BorutaFederation.Repo.Migrations.AddAuthoritiesToFederationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :authorities, {:array, :string}, null: false, default: []
      add :default, :boolean, null: false, default: false
    end
  end
end
