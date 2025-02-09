defmodule BorutaFederation.Repo.Migrations.AddMaxDepthToFederationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :max_depth, :integer
    end
  end
end
