defmodule BorutaFederation.Repo.Migrations.AddNamingConstraintsToFederationEntities do
  use Ecto.Migration

  def change do
    alter table(:federation_entities) do
      add :excluded, {:array, :string}
      add :permitted, {:array, :string}
    end
  end
end
