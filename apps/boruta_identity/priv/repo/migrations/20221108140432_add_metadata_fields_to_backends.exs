defmodule BorutaIdentity.Repo.Migrations.AddMetadataFieldsToBackends do
  use Ecto.Migration

  def change do
    alter table(:backends) do
      add :metadata_fields, {:array, :jsonb}, default: []
    end
  end
end
